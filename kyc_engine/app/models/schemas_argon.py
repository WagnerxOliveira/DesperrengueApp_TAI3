from __future__ import annotations

import re
from typing import List, Literal, Optional, Sequence, Tuple

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, model_validator

_RE_NON_DIGIT = re.compile(r"\D")
_RE_HAS_ALPHA = re.compile(r"[A-Za-z]")
_RE_MRZ_ALLOWED = re.compile(r"^[A-Z0-9<]+$")
_RE_CNH_RENACH = re.compile(r"^[A-Z]{2}\d{9}$")

# Jargões técnicos proibidos em mensagens voltadas ao usuário final (Zero Technical Jargon Gate)
_FORBIDDEN_USER_JARGON = (
    "SHAP",
    "ASN.1",
    "YCBCR",
    "DHASH",
    "PHASH",
    "MTLS",
    "TIER-0",
    "TIER-1",
    "LAPLACIANO",
    "LAPLACIAN",
    "MOD 11",
    "MOD-11",
    "MOD11",
    "PKCS#7",
    "ECDSA",
)


def _sanitize_user_guidance(text: str, fallback: str) -> str:
    cleaned = (text or "").strip()
    if not cleaned:
        return fallback
    upper = cleaned.upper()
    if any(token in upper for token in _FORBIDDEN_USER_JARGON):
        return fallback
    return cleaned


def validate_cpf_mod11(cpf_raw: Optional[str]) -> bool:
    """
    Validação matemática determinística O(1) dos dois dígitos verificadores
    Módulo 11 da Receita Federal do Brasil (RFB).
    Rejeita tamanho != 11, letras embutidas e sequências repdigit (000... a 999...).
    """
    if not cpf_raw or not isinstance(cpf_raw, str):
        return False
    if _RE_HAS_ALPHA.search(cpf_raw):
        return False
    digits = _RE_NON_DIGIT.sub("", cpf_raw)
    if len(digits) != 11 or digits == digits[0] * 11:
        return False

    for target_idx in (9, 10):
        weight_start = target_idx + 1
        total = sum(int(digits[i]) * (weight_start - i) for i in range(target_idx))
        remainder = (total * 10) % 11
        check_digit = 0 if remainder == 10 else remainder
        if int(digits[target_idx]) != check_digit:
            return False
    return True


def validate_cnpj_mod11(cnpj_raw: Optional[str]) -> bool:
    """
    Validação matemática determinística O(1) do CNPJ de 14 dígitos pelo Módulo 11
    oficial da Receita Federal (pesos 5..2, 9..2 e 6..2, 9..2), rejeitando repdigits.
    """
    if not cnpj_raw or not isinstance(cnpj_raw, str):
        return False
    if _RE_HAS_ALPHA.search(cnpj_raw):
        return False
    digits = _RE_NON_DIGIT.sub("", cnpj_raw)
    if len(digits) != 14 or digits == digits[0] * 14:
        return False

    weights_first = (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)
    weights_second = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)

    sum_first = sum(int(digits[i]) * weights_first[i] for i in range(12))
    rem_first = sum_first % 11
    dv_first = 0 if rem_first < 2 else (11 - rem_first)
    if int(digits[12]) != dv_first:
        return False

    sum_second = sum(int(digits[i]) * weights_second[i] for i in range(13))
    rem_second = sum_second % 11
    dv_second = 0 if rem_second < 2 else (11 - rem_second)
    return int(digits[13]) == dv_second


def validate_nfe_access_key_mod11(access_key_raw: Optional[str]) -> bool:
    """
    Validação determinística da Chave de Acesso de 44 dígitos de NF-e / NFC-e
    (Modelo 55 / 65) utilizando o Módulo 11 com pesos cíclicos de 2 a 9 da direita
    para a esquerda sobre os 43 primeiros dígitos.
    """
    if not access_key_raw or not isinstance(access_key_raw, str):
        return False
    if _RE_HAS_ALPHA.search(access_key_raw):
        return False
    digits = _RE_NON_DIGIT.sub("", access_key_raw)
    if len(digits) != 44 or digits == digits[0] * 44:
        return False

    total = 0
    weight = 2
    for ch in reversed(digits[:43]):
        total += int(ch) * weight
        weight = 2 if weight == 9 else (weight + 1)

    remainder = total % 11
    dv = 0 if remainder in (0, 1) else (11 - remainder)
    return int(digits[43]) == dv


def compute_icao_mrz_check_digit(field_str: str) -> int:
    """
    Cálculo oficial ICAO Doc 9303 Módulo 10 com pesos cíclicos (7, 3, 1):
    '0'-'9' -> 0..9, 'A'-'Z' -> 10..35, '<' -> 0.
    Retorna -1 caso encontre qualquer caractere inválido fora do alfabeto MRZ.
    """
    if not isinstance(field_str, str) or len(field_str) == 0:
        return -1
    weights = (7, 3, 1)
    total = 0
    for idx, ch in enumerate(field_str.upper()):
        if "0" <= ch <= "9":
            val = ord(ch) - ord("0")
        elif "A" <= ch <= "Z":
            val = ord(ch) - ord("A") + 10
        elif ch == "<":
            val = 0
        else:
            return -1
        total += val * weights[idx % 3]
    return total % 10


def _check_mrz_digit_matches(field_slice: str, expected_char: str, allow_filler_when_empty: bool = False) -> bool:
    if allow_filler_when_empty and all(c == "<" for c in field_slice) and expected_char in ("<", "0"):
        return True
    if not ("0" <= expected_char <= "9"):
        return False
    computed = compute_icao_mrz_check_digit(field_slice)
    return computed >= 0 and computed == int(expected_char)


def validate_icao_mrz_lines(mrz_lines: Sequence[str]) -> bool:
    """
    Valida linhas MRZ segundo o padrão ICAO Doc 9303:
    - TD1 (3 linhas x 30 caracteres: Nova CIN / RG Mercosul / Identidade Civil)
    - TD3 (2 linhas x 44 caracteres: Passaporte)
    Verifica todos os dígitos verificadores individuais e o dígito verificador composto (7-3-1).
    """
    if not mrz_lines or not isinstance(mrz_lines, (list, tuple)):
        return False

    cleaned = [str(line).strip().upper() for line in mrz_lines if str(line).strip()]
    if len(cleaned) == 3 and all(len(line) == 30 for line in cleaned):
        l1, l2, l3 = cleaned
        if not (_RE_MRZ_ALLOWED.match(l1) and _RE_MRZ_ALLOWED.match(l2) and _RE_MRZ_ALLOWED.match(l3)):
            return False
        # TD1:
        # l1[5:14] -> doc number, l1[14] -> check digit
        # l2[0:6]  -> birth date YYMMDD, l2[6] -> check digit
        # l2[8:14] -> expiry date YYMMDD, l2[14] -> check digit
        # l2[29]   -> composite check digit sobre l1[5:30] + l2[0:7] + l2[8:15] + l2[18:29]
        if not _check_mrz_digit_matches(l1[5:14], l1[14]):
            return False
        if not _check_mrz_digit_matches(l2[0:6], l2[6]):
            return False
        if not _check_mrz_digit_matches(l2[8:14], l2[14]):
            return False
        composite_slice = l1[5:30] + l2[0:7] + l2[8:15] + l2[18:29]
        if not _check_mrz_digit_matches(composite_slice, l2[29]):
            return False
        return True

    if len(cleaned) == 2 and all(len(line) == 44 for line in cleaned):
        l1, l2 = cleaned
        if not (_RE_MRZ_ALLOWED.match(l1) and _RE_MRZ_ALLOWED.match(l2)):
            return False
        # TD3:
        # l2[0:9]   -> passport number, l2[9] -> check digit
        # l2[13:19] -> birth date YYMMDD, l2[19] -> check digit
        # l2[21:27] -> expiry date YYMMDD, l2[27] -> check digit
        # l2[28:42] -> personal number, l2[42] -> check digit (aceita '<' se campo todo '<')
        # l2[43]    -> composite check digit sobre l2[0:10] + l2[13:20] + l2[21:43]
        if not _check_mrz_digit_matches(l2[0:9], l2[9]):
            return False
        if not _check_mrz_digit_matches(l2[13:19], l2[19]):
            return False
        if not _check_mrz_digit_matches(l2[21:27], l2[27]):
            return False
        if not _check_mrz_digit_matches(l2[28:42], l2[42], allow_filler_when_empty=True):
            return False
        composite_slice = l2[0:10] + l2[13:20] + l2[21:43]
        if not _check_mrz_digit_matches(composite_slice, l2[43]):
            return False
        return True

    return False


def validate_cnh_security_code(code_raw: Optional[str]) -> bool:
    """
    Valida o Código de Segurança de 11 dígitos da CNH (SENATRAN),
    rejeitando letras, comprimentos != 11 e sequências repdigit.
    """
    if not code_raw or not isinstance(code_raw, str):
        return False
    if _RE_HAS_ALPHA.search(code_raw):
        return False
    digits = _RE_NON_DIGIT.sub("", code_raw)
    if len(digits) != 11 or digits == digits[0] * 11:
        return False
    return True


def validate_cnh_renach(renach_raw: Optional[str]) -> bool:
    """
    Valida o número RENACH da CNH no formato oficial SENATRAN (^[A-Z]{2}\\d{9}$),
    rejeitando sequências numéricas repdigit.
    """
    if not renach_raw or not isinstance(renach_raw, str):
        return False
    cleaned = renach_raw.strip().upper()
    if not _RE_CNH_RENACH.match(cleaned):
        return False
    numeric_part = cleaned[2:]
    if numeric_part == numeric_part[0] * 9:
        return False
    return True


class NormalizedBoundingBox2D(BaseModel):
    """
    Coordenadas espaciais normalizadas na escala [0..1000] geradas pelo Grounding
    Espacial 2D do Gemini 4 Argon High.
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    ymin: int = Field(..., ge=0, le=1000, description="Coordenada Y superior (0 a 1000).")
    xmin: int = Field(..., ge=0, le=1000, description="Coordenada X esquerda (0 a 1000).")
    ymax: int = Field(..., ge=0, le=1000, description="Coordenada Y inferior (0 a 1000).")
    xmax: int = Field(..., ge=0, le=1000, description="Coordenada X direita (0 a 1000).")
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)

    @model_validator(mode="after")
    def _validate_box_geometry(self) -> NormalizedBoundingBox2D:
        if self.ymax <= self.ymin:
            raise ValueError(f"ymax ({self.ymax}) deve ser estritamente maior que ymin ({self.ymin}).")
        if self.xmax <= self.xmin:
            raise ValueError(f"xmax ({self.xmax}) deve ser estritamente maior que xmin ({self.xmin}).")
        return self

    def to_pixel_crop(
        self,
        img_width: int,
        img_height: int,
        pad_ratio: float = 0.04,
    ) -> Tuple[int, int, int, int]:
        """
        Converte a caixa normalizada [0..1000] em coordenadas de pixels (left, top, right, bottom)
        aplicando margem de segurança (pad_ratio) e clamp seguro nas bordas da imagem.
        """
        if img_width <= 0 or img_height <= 0:
            raise ValueError("As dimensões da imagem (img_width, img_height) devem ser positivas.")
        if pad_ratio < 0.0:
            raise ValueError("pad_ratio não pode ser negativo.")

        raw_left = (self.xmin / 1000.0) * img_width
        raw_top = (self.ymin / 1000.0) * img_height
        raw_right = (self.xmax / 1000.0) * img_width
        raw_bottom = (self.ymax / 1000.0) * img_height

        box_w = raw_right - raw_left
        box_h = raw_bottom - raw_top
        pad_x = box_w * pad_ratio
        pad_y = box_h * pad_ratio

        left = max(0, min(img_width - 1, int(round(raw_left - pad_x))))
        top = max(0, min(img_height - 1, int(round(raw_top - pad_y))))
        right = max(left + 1, min(img_width, int(round(raw_right + pad_x))))
        bottom = max(top + 1, min(img_height, int(round(raw_bottom + pad_y))))
        return (left, top, right, bottom)


class OpticalForensicsAndQualityGate(BaseModel):
    """
    Portão de qualidade óptica, detecção de rotação canônica e blindagem contra
    fraudes visuais (replay de tela/Moiré, colagem 3x4 e Visual Prompt Injection).
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    is_readable: bool
    canonical_rotation_deg: Literal[0, 90, 180, 270] = 0
    is_full_document_visible: bool
    has_glare_on_critical_zones: bool
    glare_zone_description: Optional[str] = None
    is_screen_replay_or_moire_suspected: bool
    has_portrait_paste_or_font_tampering: bool
    adversarial_prompt_injection_detected: bool
    detected_document_type: Literal["CNH", "CIN", "RG", "PASSPORT", "UNKNOWN"]

    @model_validator(mode="after")
    def _enforce_hard_optical_vetos(self) -> OpticalForensicsAndQualityGate:
        if (
            self.adversarial_prompt_injection_detected
            or self.is_screen_replay_or_moire_suspected
            or self.has_portrait_paste_or_font_tampering
            or self.has_glare_on_critical_zones
            or not self.is_full_document_visible
        ):
            object.__setattr__(self, "is_readable", False)
        return self


class SpatialRegionsOfInterest(BaseModel):
    """
    Regiões de interesse (ROIs) ancoradas espacialmente na escala [0..1000].
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    face_portrait_box_2d: Optional[NormalizedBoundingBox2D] = None
    qr_code_vio_box_2d: Optional[NormalizedBoundingBox2D] = None
    signature_box_2d: Optional[NormalizedBoundingBox2D] = None
    mrz_box_2d: Optional[NormalizedBoundingBox2D] = None


class ExtractedDocumentDossierArgon(BaseModel):
    """
    Dossiê completo extraído e validado pelo Gemini 4 Argon High (Tier-1),
    combinando qualidade óptica, Grounding 2D, OCR Frente/Verso, checksums
    determinísticos e explicabilidade LGPD Art. 20 (SHAP).
    """

    model_config = ConfigDict(
        extra="ignore",
        populate_by_name=True,
        validate_assignment=True,
    )

    quality_gate: OpticalForensicsAndQualityGate
    spatial_rois: SpatialRegionsOfInterest = Field(
        default_factory=SpatialRegionsOfInterest,
        validation_alias=AliasChoices("spatial_rois", "spatial_roi"),
    )
    full_civil_name: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("full_civil_name", "full_name"),
    )
    cpf_11_digits: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("cpf_11_digits", "cpf"),
    )
    birth_date_iso: Optional[str] = None
    rg_or_cin_number: Optional[str] = None
    issuing_authority_uf: Optional[str] = None
    cnh_register_number: Optional[str] = None
    cnh_security_code_11: Optional[str] = None
    cnh_renach: Optional[str] = None
    issue_date_iso: Optional[str] = None
    expiry_date_iso: Optional[str] = None
    mrz_raw_lines: Optional[List[str]] = None
    front_back_cpf_consistent: bool = False
    cpf_mod11_valid: bool = False
    mrz_checksums_valid: Optional[bool] = None
    shap_top_3_explainability_factors: List[str] = Field(
        default_factory=lambda: [
            "Nitidez óptica e enquadramento integral das quatro bordas verificados.",
            "Consistência documental entre Frente e Verso avaliada.",
            "Validação aritmética dos identificadores civis concluída.",
        ],
        min_length=3,
        max_length=3,
    )
    user_friendly_retake_guidance: str = Field(
        default=(
            "Documento lido com clareza. Caso precise refazer a foto, apoie o documento "
            "aberto sobre uma mesa bem iluminada e evite o uso de flash."
        )
    )

    @property
    def spatial_roi(self) -> SpatialRegionsOfInterest:
        return self.spatial_rois

    @property
    def full_name(self) -> Optional[str]:
        return self.full_civil_name

    @property
    def cpf(self) -> Optional[str]:
        return self.cpf_11_digits

    @model_validator(mode="after")
    def _recalculate_deterministic_integrity(self) -> ExtractedDocumentDossierArgon:
        # 1. Normalização e validação determinística do CPF (Módulo 11 RFB)
        if self.cpf_11_digits:
            is_valid_cpf = validate_cpf_mod11(self.cpf_11_digits)
            digits_only = _RE_NON_DIGIT.sub("", self.cpf_11_digits)
            if len(digits_only) == 11:
                object.__setattr__(self, "cpf_11_digits", digits_only)
            object.__setattr__(self, "cpf_mod11_valid", is_valid_cpf)
            if not is_valid_cpf:
                object.__setattr__(self, "front_back_cpf_consistent", False)
        else:
            object.__setattr__(self, "cpf_mod11_valid", False)
            object.__setattr__(self, "front_back_cpf_consistent", False)

        # 2. Validação determinística do MRZ ICAO Doc 9303 (pesos 7-3-1) quando presente
        if self.mrz_raw_lines is not None:
            mrz_ok = validate_icao_mrz_lines(self.mrz_raw_lines)
            object.__setattr__(self, "mrz_checksums_valid", mrz_ok)

        # 3. Garantia estrita de 3 fatores de explicabilidade LGPD Art. 20
        factors = [str(f).strip() for f in (self.shap_top_3_explainability_factors or []) if str(f).strip()]
        if len(factors) != 3:
            raise ValueError("shap_top_3_explainability_factors deve conter exatamente 3 itens não-vazios (LGPD Art. 20).")
        object.__setattr__(self, "shap_top_3_explainability_factors", factors)

        # 4. Sanitização de linguagem humana (zero jargão técnico para o usuário final)
        default_guidance = (
            "Posicione o documento aberto sobre uma superfície plana e bem iluminada, "
            "evitando reflexos de luz sobre a foto e os dados."
        )
        sanitized_guidance = _sanitize_user_guidance(self.user_friendly_retake_guidance, default_guidance)
        object.__setattr__(self, "user_friendly_retake_guidance", sanitized_guidance)
        return self


class FiscalInvoiceLineItemArgon(BaseModel):
    """
    Item individual extraído de Nota Fiscal (DANFE NF-e / Cupom NFC-e) na auditoria
    do Smart Split (0% de taxa sobre materiais consumíveis da obra/serviço).
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    description: str = Field(..., min_length=1)
    ncm_code: Optional[str] = None
    quantity: float = Field(..., gt=0.0)
    unit_price_cents: int = Field(..., ge=0)
    total_price_cents: int = Field(..., ge=0)
    is_consumable_material: bool = True


class FiscalInvoiceAuditArgon(BaseModel):
    """
    Resultado da auditoria forense de Nota Fiscal de Materiais pelo Gemini 4 Argon High
    para proteção do Smart Split (0% em peças).
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    is_legitimate_fiscal_document: bool = True
    adversarial_prompt_injection_detected: bool = False
    access_key_44_digits: Optional[str] = None
    access_key_mod11_valid: bool = False
    issuer_cnpj_14_digits: Optional[str] = None
    issuer_cnpj_mod11_valid: bool = False
    issuer_corporate_name: Optional[str] = None
    issue_timestamp_iso: Optional[str] = None
    line_items: List[FiscalInvoiceLineItemArgon] = Field(default_factory=list)
    declared_total_cents: int = Field(..., ge=0)
    computed_materials_sum_cents: int = Field(default=0, ge=0)
    arithmetic_sum_consistent: bool = False
    shap_top_3_explainability_factors: List[str] = Field(
        default_factory=lambda: [
            "Chave de acesso de 44 dígitos verificada matematicamente.",
            "Cadastro fiscal do estabelecimento emissor conferido.",
            "Soma dos materiais consumíveis confrontada com o valor declarado.",
        ],
        min_length=3,
        max_length=3,
    )
    user_friendly_feedback: str = Field(
        default="Comprovante fiscal de materiais conferido com sucesso."
    )

    @model_validator(mode="after")
    def _validate_fiscal_integrity_and_smart_split(self) -> FiscalInvoiceAuditArgon:
        # 1. Validação Módulo 11 da Chave de Acesso de 44 dígitos
        if self.access_key_44_digits:
            key_ok = validate_nfe_access_key_mod11(self.access_key_44_digits)
            clean_key = _RE_NON_DIGIT.sub("", self.access_key_44_digits)
            if len(clean_key) == 44:
                object.__setattr__(self, "access_key_44_digits", clean_key)
            object.__setattr__(self, "access_key_mod11_valid", key_ok)
        else:
            object.__setattr__(self, "access_key_mod11_valid", False)

        # 2. Validação Módulo 11 do CNPJ de 14 dígitos
        if self.issuer_cnpj_14_digits:
            cnpj_ok = validate_cnpj_mod11(self.issuer_cnpj_14_digits)
            clean_cnpj = _RE_NON_DIGIT.sub("", self.issuer_cnpj_14_digits)
            if len(clean_cnpj) == 14:
                object.__setattr__(self, "issuer_cnpj_14_digits", clean_cnpj)
            object.__setattr__(self, "issuer_cnpj_mod11_valid", cnpj_ok)
        else:
            object.__setattr__(self, "issuer_cnpj_mod11_valid", False)

        # 3. Cálculo determinístico da soma de insumos consumíveis e consistência aritmética
        items_internally_consistent = True
        if self.line_items:
            consumable_total = 0
            for item in self.line_items:
                expected_item_total = int(round(item.quantity * item.unit_price_cents))
                if abs(expected_item_total - item.total_price_cents) > 5:
                    items_internally_consistent = False
                if item.is_consumable_material:
                    consumable_total += item.total_price_cents
            object.__setattr__(self, "computed_materials_sum_cents", consumable_total)

        sum_matches_declared = (
            self.declared_total_cents > 0
            and items_internally_consistent
            and abs(self.computed_materials_sum_cents - self.declared_total_cents) <= 5
        )
        object.__setattr__(self, "arithmetic_sum_consistent", sum_matches_declared)

        # 4. Veto determinístico se houver Prompt Injection, chave inválida, CNPJ inválido ou divergência de soma
        if (
            self.adversarial_prompt_injection_detected
            or not self.access_key_mod11_valid
            or not self.issuer_cnpj_mod11_valid
            or not self.arithmetic_sum_consistent
        ):
            object.__setattr__(self, "is_legitimate_fiscal_document", False)

        # 5. Garantia estrita dos 3 fatores SHAP (LGPD Art. 20)
        factors = [str(f).strip() for f in (self.shap_top_3_explainability_factors or []) if str(f).strip()]
        if len(factors) != 3:
            raise ValueError("shap_top_3_explainability_factors deve conter exatamente 3 itens não-vazios (LGPD Art. 20).")
        object.__setattr__(self, "shap_top_3_explainability_factors", factors)

        # 6. Sanitização de mensagem amigável sem jargões técnicos
        default_feedback = (
            "Comprovante de materiais validado com sucesso."
            if self.is_legitimate_fiscal_document
            else "Não foi possível validar o comprovante de materiais. Verifique se a nota está legível e se inclui apenas materiais utilizados no serviço."
        )
        sanitized_feedback = _sanitize_user_guidance(self.user_friendly_feedback, default_feedback)
        object.__setattr__(self, "user_friendly_feedback", sanitized_feedback)
        return self
