"""Exhaustive Cryptographic, Anti-Swap, SERPRO mTLS, Orchestrator & FastAPI Red-Team Suite (FRENTE 1)."""

from __future__ import annotations

import asyncio
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import logging
import ssl
from typing import Tuple
import zlib

from asn1crypto import algos, cms, core, x509 as asn1_x509
from cryptography import x509
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.x509.oid import NameOID
from fastapi.testclient import TestClient
import httpx
from PIL import Image
import pytest
import qrcode

from app.core.config import KYCZeroTrustSettings, _HOMOLOGATION_MASTER_KEK_HEX
from app.core.security import (
    HardwareAttestationVerdict,
    PiiRedactingLogFilter,
    ZeroTrustSecurityEngine,
    redact_pii_text,
)
from app.main import create_kyc_app
from app.services.crypto_doc_validator import (
    DataGroupHash,
    DataGroupHashValues,
    GovCryptographicDocumentValidator,
    LDSSecurityObject,
    ZipBombDetectedError,
    der_to_ieee_p1363_signature,
    ieee_p1363_to_der_signature,
)
from app.services.fraud_orchestrator import (
    ArgonProcessedArtifacts,
    CarbonFraudOrchestrator,
    ExtractedDocumentDossierArgon,
    OpticalForensicsAndQualityGate,
    SpatialRegionsOfInterest,
    _CarbonLLMCorrelationSchema,
    sanitize_human_message_ptbr,
)
from app.services.serpro_datavalid import (
    CircuitState,
    SerproBiometricResult,
    SerproCircuitOpenError,
    SerproDatavalidMtlsClient,
)

VALID_CPF_A = "52998224725"  # Valid Mod-11 CPF
VALID_CPF_B = "11144477735"  # Distinct valid Mod-11 CPF (used to simulate cloned VIO QR)


# ==============================================================================
# Cryptographic PKI, CMS/PKCS#7, QR Optical & ICAO 9303 NFC Builders for Tests
# ==============================================================================


def _generate_ecdsa_pki_hierarchy(
    *, expired_leaf: bool = False
) -> Tuple[
    ec.EllipticCurvePrivateKey,
    x509.Certificate,
    ec.EllipticCurvePrivateKey,
    x509.Certificate,
]:
    now = datetime.now(timezone.utc)
    root_key = ec.generate_private_key(ec.SECP256R1())
    root_subject = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "ICP-Brasil"),
            x509.NameAttribute(NameOID.COMMON_NAME, "AC Raiz ICP-Brasil Test v10"),
        ]
    )
    root_cert = (
        x509.CertificateBuilder()
        .subject_name(root_subject)
        .issuer_name(root_subject)
        .public_key(root_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=365))
        .not_valid_after(now + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=True, path_length=2), critical=True)
        .add_extension(
            x509.SubjectKeyIdentifier.from_public_key(root_key.public_key()),
            critical=False,
        )
        .sign(root_key, hashes.SHA256())
    )

    leaf_key = ec.generate_private_key(ec.SECP256R1())
    leaf_subject = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "SENATRAN SERPRO"),
            x509.NameAttribute(NameOID.COMMON_NAME, "Emissor VIO CNH Digital ECDSA"),
        ]
    )
    valid_from = now - timedelta(days=400) if expired_leaf else now - timedelta(days=30)
    valid_until = now - timedelta(days=10) if expired_leaf else now + timedelta(days=365)

    leaf_cert = (
        x509.CertificateBuilder()
        .subject_name(leaf_subject)
        .issuer_name(root_subject)
        .public_key(leaf_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(valid_from)
        .not_valid_after(valid_until)
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.SubjectKeyIdentifier.from_public_key(leaf_key.public_key()),
            critical=False,
        )
        .sign(root_key, hashes.SHA256())
    )
    return root_key, root_cert, leaf_key, leaf_cert


def _generate_rsa_pki_hierarchy() -> Tuple[
    rsa.RSAPrivateKey, x509.Certificate, rsa.RSAPrivateKey, x509.Certificate
]:
    now = datetime.now(timezone.utc)
    root_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    root_name = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "ICP-Brasil CSCA"),
            x509.NameAttribute(NameOID.COMMON_NAME, "CSCA Brasil Nova CIN RSA Root"),
        ]
    )
    root_cert = (
        x509.CertificateBuilder()
        .subject_name(root_name)
        .issuer_name(root_name)
        .public_key(root_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=365))
        .not_valid_after(now + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=True, path_length=2), critical=True)
        .sign(root_key, hashes.SHA256())
    )

    leaf_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf_name = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Document Signer CIN"),
            x509.NameAttribute(NameOID.COMMON_NAME, "DS CIN RSA-2048"),
        ]
    )
    leaf_cert = (
        x509.CertificateBuilder()
        .subject_name(leaf_name)
        .issuer_name(root_name)
        .public_key(leaf_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=10))
        .not_valid_after(now + timedelta(days=365))
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .sign(root_key, hashes.SHA256())
    )
    return root_key, root_cert, leaf_key, leaf_cert


def _build_cms_signed_data_der(
    *,
    payload_bytes: bytes,
    signer_key: ec.EllipticCurvePrivateKey | rsa.RSAPrivateKey,
    signer_cert: x509.Certificate,
    extra_certs: tuple[x509.Certificate, ...] = (),
    use_signed_attrs: bool = True,
    use_ieee_p1363_ecdsa: bool = False,
    use_rsa_pss: bool = False,
    content_type_oid: str = "data",
    tamper_encap_after_sign: bool = False,
    tamper_signature_after_sign: bool = False,
) -> bytes:
    cert_der = signer_cert.public_bytes(serialization.Encoding.DER)
    asn1_cert = asn1_x509.Certificate.load(cert_der)
    asn1_cert_choices = [cms.CertificateChoices({"certificate": asn1_cert})]
    for extra in extra_certs:
        extra_asn1 = asn1_x509.Certificate.load(
            extra.public_bytes(serialization.Encoding.DER)
        )
        asn1_cert_choices.append(cms.CertificateChoices({"certificate": extra_asn1}))

    signed_attrs_obj = None
    if use_signed_attrs:
        digest = hashlib.sha256(payload_bytes).digest()
        signed_attrs_obj = cms.CMSAttributes(
            [
                cms.CMSAttribute(
                    {"type": "content_type", "values": [content_type_oid]}
                ),
                cms.CMSAttribute({"type": "message_digest", "values": [digest]}),
            ]
        )
        dumped_attrs = signed_attrs_obj.dump()
        to_sign = b"\x31" + dumped_attrs[1:]
    else:
        to_sign = payload_bytes

    if isinstance(signer_key, ec.EllipticCurvePrivateKey):
        der_sig = signer_key.sign(to_sign, ec.ECDSA(hashes.SHA256()))
        sig_bytes = (
            der_to_ieee_p1363_signature(der_sig, coord_size=32)
            if use_ieee_p1363_ecdsa
            else der_sig
        )
        sig_alg = algos.SignedDigestAlgorithm({"algorithm": "sha256_ecdsa"})
    else:
        if use_rsa_pss:
            sig_bytes = signer_key.sign(
                to_sign,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=32,
                ),
                hashes.SHA256(),
            )
            sig_alg = algos.SignedDigestAlgorithm(
                {
                    "algorithm": "rsassa_pss",
                    "parameters": algos.RSASSAPSSParams(
                        {
                            "hash_algorithm": {"algorithm": "sha256"},
                            "mask_gen_algorithm": {
                                "algorithm": "mgf1",
                                "parameters": {"algorithm": "sha256"},
                            },
                            "salt_length": 32,
                        }
                    ),
                }
            )
        else:
            sig_bytes = signer_key.sign(to_sign, padding.PKCS1v15(), hashes.SHA256())
            sig_alg = algos.SignedDigestAlgorithm({"algorithm": "sha256_rsa"})

    if tamper_signature_after_sign:
        mut = bytearray(sig_bytes)
        mut[-1] ^= 0xFF
        sig_bytes = bytes(mut)

    encap_payload = payload_bytes + b"TAMPER" if tamper_encap_after_sign else payload_bytes

    signer_info_dict = {
        "version": "v1",
        "sid": cms.SignerIdentifier(
            {
                "issuer_and_serial_number": cms.IssuerAndSerialNumber(
                    {
                        "issuer": asn1_cert.issuer,
                        "serial_number": asn1_cert.serial_number,
                    }
                )
            }
        ),
        "digest_algorithm": algos.DigestAlgorithm({"algorithm": "sha256"}),
        "signature_algorithm": sig_alg,
        "signature": sig_bytes,
    }
    if signed_attrs_obj is not None:
        signer_info_dict["signed_attrs"] = signed_attrs_obj

    signed_data = cms.SignedData(
        {
            "version": "v1",
            "digest_algorithms": [algos.DigestAlgorithm({"algorithm": "sha256"})],
            "encap_content_info": {
                "content_type": content_type_oid,
                "content": core.OctetString(encap_payload),
            },
            "certificates": asn1_cert_choices,
            "signer_infos": [cms.SignerInfo(signer_info_dict)],
        }
    )
    return cms.ContentInfo(
        {"content_type": "signed_data", "content": signed_data}
    ).dump()


def _render_vio_qr_png(raw_bytes: bytes, *, low_contrast_small: bool = False) -> bytes:
    b64_ascii = b"VIO1:" + base64.urlsafe_b64encode(zlib.compress(raw_bytes, level=9))
    qr = qrcode.QRCode(
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=3 if low_contrast_small else 5,
        border=4,
    )
    qr.add_data(b64_ascii)
    qr.make(fit=True)
    fill = (70, 70, 70) if low_contrast_small else "black"
    back = (210, 210, 210) if low_contrast_small else "white"
    pil_img = qr.make_image(fill_color=fill, back_color=back).convert("RGB")
    buf = io.BytesIO()
    pil_img.save(buf, format="PNG")
    return buf.getvalue()


def _make_jpeg_bytes(
    width: int = 800, height: int = 500, color: tuple = (240, 240, 245), comment: bytes = b""
) -> bytes:
    img = Image.new("RGB", (width, height), color=color)
    buf = io.BytesIO()
    save_kwargs = {"format": "JPEG", "quality": 92}
    if comment:
        save_kwargs["comment"] = comment
    img.save(buf, **save_kwargs)
    return buf.getvalue()


def _wrap_icao_tag_77(cms_der: bytes) -> bytes:
    length = len(cms_der)
    if length < 0x80:
        header = bytes([0x77, length])
    elif length <= 0xFF:
        header = bytes([0x77, 0x81, length])
    else:
        header = bytes([0x77, 0x82, (length >> 8) & 0xFF, length & 0xFF])
    return header + cms_der


def _make_clean_argon_artifacts(
    *,
    cpf: str = VALID_CPF_A,
    full_name: str = "WAGNER OLIVEIRA CLAUDIANO",
    typed_name_score: float = 1.0,
    is_readable: bool = True,
    prompt_injection: bool = False,
    screen_replay: bool = False,
    front_back_consistent: bool = True,
    mrz_valid: bool | None = None,
    cnh_security_code_11: str | None = None,
    cnh_renach: str | None = None,
    ready_override: bool | None = None,
    doc_type: str = "CNH",
    qr_png: bytes | None = None,
) -> ArgonProcessedArtifacts:
    front_jpeg = _make_jpeg_bytes()
    back_jpeg = _make_jpeg_bytes()
    dossier = ExtractedDocumentDossierArgon(
        quality_gate=OpticalForensicsAndQualityGate(
            is_readable=is_readable,
            canonical_rotation_deg=0,
            is_full_document_visible=is_readable,
            has_glare_on_critical_zones=False,
            is_screen_replay_or_moire_suspected=screen_replay,
            has_portrait_paste_or_font_tampering=False,
            adversarial_prompt_injection_detected=prompt_injection,
            detected_document_type=doc_type,  # type: ignore[arg-type]
        ),
        spatial_rois=SpatialRegionsOfInterest(),
        full_civil_name=full_name,
        cpf_11_digits=cpf,
        cnh_security_code_11=cnh_security_code_11,
        cnh_renach=cnh_renach,
        front_back_cpf_consistent=front_back_consistent,
        cpf_mod11_valid=True,
        mrz_checksums_valid=mrz_valid,
        shap_top_3_explainability_factors=[
            "Nitidez óptica e quatro bordas verificadas.",
            "Consistência entre frente e verso confirmada.",
            "Identificadores civis extraídos sem divergências.",
        ],
        user_friendly_retake_guidance="Documento lido com clareza.",
    )
    if mrz_valid is not None:
        object.__setattr__(dossier, "mrz_checksums_valid", mrz_valid)
    default_ready = is_readable and not prompt_injection and not screen_replay
    return ArgonProcessedArtifacts(
        dossier=dossier,
        cropped_portrait_3x4_jpeg=front_jpeg,
        cropped_qr_code_vio_png=qr_png,
        canonical_front_jpeg=front_jpeg,
        canonical_back_jpeg=back_jpeg,
        ready_for_serpro_and_carbon=(
            ready_override if ready_override is not None else default_ready
        ),
        name_compatibility_score=typed_name_score,
    )


# ==============================================================================
# 1. Configuration, WORM AES-256-GCM, Anti-Sybil & LGPD Log Redaction Tests
# ==============================================================================


def test_production_settings_reject_missing_or_homologation_secrets() -> None:
    default_cfg = KYCZeroTrustSettings(environment="homologation")
    assert not default_cfg.is_production
    assert len(bytes.fromhex(default_cfg.master_kek_hex)) == 32

    with pytest.raises(ValueError, match="Segredos obrigatórios ausentes"):
        KYCZeroTrustSettings(environment="production")

    with pytest.raises(ValueError, match="Chave de homologação não é permitida"):
        KYCZeroTrustSettings(
            environment="production",
            master_kek_hex=_HOMOLOGATION_MASTER_KEK_HEX,
            cpf_pepper_secret="prod-pepper-xyz",
            session_hmac_secret="prod-session-xyz",
            supabase_webhook_secret="prod-webhook-xyz",
            supabase_webhook_url="https://prod.supabase.co/functions/v1/kyc-carbon-webhook",
            gemini_api_key="prod-gemini-key",
        )

    with pytest.raises(ValueError, match="32 bytes"):
        KYCZeroTrustSettings(environment="homologation", master_kek_hex="abcd1234")


def test_worm_aes256_gcm_hkdf_roundtrip_and_tamper_detection() -> None:
    sec = ZeroTrustSecurityEngine()
    plaintext = b'{"cpf_hash":"abc123","verdict":"APPROVED"}'
    aad = b"user-001:session-nonce-xyz"

    blob_1 = sec.encrypt_evidence_worm(plaintext, aad)
    blob_2 = sec.encrypt_evidence_worm(plaintext, aad)

    # Fresh CSPRNG 16B salt + 12B nonce guarantees semantic security (IND-CPA / IND-CCA2)
    assert blob_1 != blob_2
    assert blob_1.startswith(b"KWV2")
    assert sec.decrypt_evidence_worm(blob_1, aad) == plaintext
    assert sec.decrypt_evidence_worm(blob_2, aad) == plaintext

    # Tampered AAD must fail GCM tag verification immediately
    with pytest.raises(InvalidTag):
        sec.decrypt_evidence_worm(blob_1, b"user-002:session-nonce-xyz")

    # Single bit flip in ciphertext/tag must fail GCM authentication
    corrupted = bytearray(blob_1)
    corrupted[-1] ^= 0x01
    with pytest.raises(InvalidTag):
        sec.decrypt_evidence_worm(bytes(corrupted), aad)

    with pytest.raises(ValueError, match="Envelope WORM inválido"):
        sec.decrypt_evidence_worm(b"BAD!" + blob_1[4:], aad)


def test_anti_sybil_hmac_lgpd_masking_and_log_filter_redaction() -> None:
    sec = ZeroTrustSecurityEngine()
    h1 = sec.hash_cpf_anti_sybil("529.982.247-25")
    h2 = sec.hash_cpf_anti_sybil("52998224725")
    h_other = sec.hash_cpf_anti_sybil(VALID_CPF_B)

    assert h1 == h2
    assert h1 != h_other
    assert len(h1) == 64
    assert sec.mask_cpf_lgpd("52998224725") == "***.982.247-**"
    assert sec.mask_cpf_lgpd("invalid") == "***.***.***-**"

    face_h = sec.hash_biometric_liveness(b"canonical-selfie-jpeg-bytes")
    assert len(face_h) == 64

    log_stream = io.StringIO()
    handler = logging.StreamHandler(log_stream)
    test_logger = logging.getLogger("test.lgpd.redaction.suite")
    test_logger.handlers = [handler]
    test_logger.setLevel(logging.INFO)
    test_logger.addFilter(PiiRedactingLogFilter())

    test_logger.info(
        "Falha CPF %s e bruto %s com Authorization: Bearer superSecretToken123456 e x-kyc-signature=deadbeefcafebabe1234",
        "529.982.247-25",
        "52998224725",
    )
    logged_output = log_stream.getvalue()
    assert "529.982.247-25" not in logged_output
    assert "52998224725" not in logged_output
    assert "superSecretToken123456" not in logged_output
    assert "deadbeefcafebabe1234" not in logged_output
    assert "***.982.247-**" in logged_output
    assert "[REDACTED_SECRET]" in logged_output
    assert VALID_CPF_A not in redact_pii_text(f"CPF={VALID_CPF_A}")


# ==============================================================================
# 2. Anti-Swap (<= 180s / <= 90s), Live Camera, VCam & Hardware Attestation
# ==============================================================================


def test_anti_swap_valid_android_ios_and_web_limited_alcada() -> None:
    sec = ZeroTrustSecurityEngine()
    t0 = 1_762_940_000
    selfie_h = sec.sha256_hex(b"selfie-1")
    front_h = sec.sha256_hex(b"front-1")
    back_h = sec.sha256_hex(b"back-1")

    # Android Play Integrity MEETS_STRONG_INTEGRITY
    ch_and = sec.issue_anti_swap_session_token("user-uuid-1", now_ts=t0)
    req_and = sec.compute_anti_swap_request_hash(
        "user-uuid-1", ch_and.session_nonce, selfie_h, front_h, back_h
    )
    res_and = sec.verify_anti_swap_and_device_integrity(
        user_id="user-uuid-1",
        session_nonce=ch_and.session_nonce,
        session_issued_at=ch_and.issued_at,
        session_signature=ch_and.session_signature,
        liveness_timestamp=t0 + 25,
        doc_capture_timestamp=t0 + 70,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=req_and,
        platform="ANDROID",
        attestation_verdict=HardwareAttestationVerdict.MEETS_STRONG_INTEGRITY,
        now_ts=t0 + 80,
    )
    assert res_and.valid is True
    assert res_and.alcada_restriction is None

    # iOS DCAppAttestService DC_APP_ATTEST_VERIFIED
    ch_ios = sec.issue_anti_swap_session_token("user-uuid-2", now_ts=t0)
    req_ios = sec.compute_anti_swap_request_hash(
        "user-uuid-2", ch_ios.session_nonce, selfie_h, front_h, back_h
    )
    res_ios = sec.verify_anti_swap_and_device_integrity(
        user_id="user-uuid-2",
        session_nonce=ch_ios.session_nonce,
        session_issued_at=ch_ios.issued_at,
        session_signature=ch_ios.session_signature,
        liveness_timestamp=t0 + 15,
        doc_capture_timestamp=t0 + 45,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=req_ios,
        platform="IOS",
        attestation_verdict=HardwareAttestationVerdict.DC_APP_ATTEST_VERIFIED,
        now_ts=t0 + 50,
    )
    assert res_ios.valid is True
    assert res_ios.alcada_restriction is None

    # PWA / Web controlled fallback -> WEB_LIMITED_ALCADA
    ch_web = sec.issue_anti_swap_session_token("user-uuid-3", now_ts=t0)
    req_web = sec.compute_anti_swap_request_hash(
        "user-uuid-3", ch_web.session_nonce, selfie_h, front_h, back_h
    )
    res_web = sec.verify_anti_swap_and_device_integrity(
        user_id="user-uuid-3",
        session_nonce=ch_web.session_nonce,
        session_issued_at=ch_web.issued_at,
        session_signature=ch_web.session_signature,
        liveness_timestamp=t0 + 15,
        doc_capture_timestamp=t0 + 35,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=req_web,
        platform="WEB",
        attestation_verdict=HardwareAttestationVerdict.WEB_LIMITED_ALCADA,
        now_ts=t0 + 40,
    )
    assert res_web.valid is True
    assert res_web.alcada_restriction == "WEB_LIMITED_ALCADA"


def test_anti_swap_blocks_replay_expired_ttl_liveness_window_and_hash_swap() -> None:
    sec = ZeroTrustSecurityEngine()
    t0 = 1_762_940_000
    selfie_h = sec.sha256_hex(b"selfie-1")
    front_h = sec.sha256_hex(b"front-1")
    back_h = sec.sha256_hex(b"back-1")

    # Replay detection
    ch = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
    rh = sec.compute_anti_swap_request_hash("u-1", ch.session_nonce, selfie_h, front_h, back_h)
    assert sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 10,
        doc_capture_timestamp=t0 + 20,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=rh,
        now_ts=t0 + 25,
    ).valid
    replay = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 10,
        doc_capture_timestamp=t0 + 20,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=rh,
        now_ts=t0 + 26,
    )
    assert not replay.valid and replay.reason_code == "SESSION_REPLAY_DETECTED"

    # Liveness window > 90s blocked
    ch_lw = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
    rh_lw = sec.compute_anti_swap_request_hash("u-1", ch_lw.session_nonce, selfie_h, front_h, back_h)
    lw_res = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch_lw.session_nonce,
        session_issued_at=ch_lw.issued_at,
        session_signature=ch_lw.session_signature,
        liveness_timestamp=t0 + 91,
        doc_capture_timestamp=t0 + 110,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=rh_lw,
        now_ts=t0 + 115,
    )
    assert not lw_res.valid and lw_res.reason_code == "LIVENESS_WINDOW_EXCEEDED"

    # Session TTL > 180s blocked
    ch_ttl = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
    rh_ttl = sec.compute_anti_swap_request_hash("u-1", ch_ttl.session_nonce, selfie_h, front_h, back_h)
    ttl_res = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch_ttl.session_nonce,
        session_issued_at=ch_ttl.issued_at,
        session_signature=ch_ttl.session_signature,
        liveness_timestamp=t0 + 30,
        doc_capture_timestamp=t0 + 175,
        selfie_hash=selfie_h,
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=rh_ttl,
        now_ts=t0 + 181,
    )
    assert not ttl_res.valid and ttl_res.reason_code == "SESSION_TTL_EXPIRED"

    # Selfie hash swap blocked
    ch_sw = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
    rh_sw = sec.compute_anti_swap_request_hash("u-1", ch_sw.session_nonce, selfie_h, front_h, back_h)
    sw_res = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch_sw.session_nonce,
        session_issued_at=ch_sw.issued_at,
        session_signature=ch_sw.session_signature,
        liveness_timestamp=t0 + 15,
        doc_capture_timestamp=t0 + 30,
        selfie_hash=sec.sha256_hex(b"swapped-selfie"),
        doc_front_hash=front_h,
        doc_back_hash=back_h,
        request_hash=rh_sw,
        now_ts=t0 + 35,
    )
    assert not sw_res.valid and sw_res.reason_code == "REQUEST_HASH_MISMATCH"


def test_anti_swap_blocks_gallery_virtual_camera_invalid_hmac_and_rooted_device() -> None:
    sec = ZeroTrustSecurityEngine(environment="production")
    t0 = 1_762_940_000
    sh = sec.sha256_hex(b"s")
    fh = sec.sha256_hex(b"f")
    bh = sec.sha256_hex(b"b")

    # Forged HMAC signature
    ch = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
    rh = sec.compute_anti_swap_request_hash("u-1", ch.session_nonce, sh, fh, bh)
    bad_hmac = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature="0" * 64,
        liveness_timestamp=t0 + 5,
        doc_capture_timestamp=t0 + 10,
        selfie_hash=sh,
        doc_front_hash=fh,
        doc_back_hash=bh,
        request_hash=rh,
        now_ts=t0 + 15,
    )
    assert not bad_hmac.valid and bad_hmac.reason_code == "INVALID_SESSION_HMAC"

    # Gallery upload blocked
    gal = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 5,
        doc_capture_timestamp=t0 + 10,
        selfie_hash=sh,
        doc_front_hash=fh,
        doc_back_hash=bh,
        request_hash=rh,
        capture_source="GALLERY",
        now_ts=t0 + 15,
    )
    assert not gal.valid and gal.reason_code == "GALLERY_UPLOAD_BLOCKED"

    # OBS / Magisk VCam blocked
    vcam = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 5,
        doc_capture_timestamp=t0 + 10,
        selfie_hash=sh,
        doc_front_hash=fh,
        doc_back_hash=bh,
        request_hash=rh,
        camera_device_label="Magisk VCam Hook",
        now_ts=t0 + 15,
    )
    assert not vcam.valid and vcam.reason_code == "VIRTUAL_CAMERA_SUSPECTED"

    # Production Android rejects non-MEETS_STRONG_INTEGRITY fallback
    prod_and = sec.verify_anti_swap_and_device_integrity(
        user_id="u-1",
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 5,
        doc_capture_timestamp=t0 + 10,
        selfie_hash=sh,
        doc_front_hash=fh,
        doc_back_hash=bh,
        request_hash=rh,
        platform="ANDROID",
        attestation_verdict=HardwareAttestationVerdict.WEB_LIMITED_ALCADA,
        now_ts=t0 + 15,
    )
    assert not prod_and.valid and prod_and.reason_code == "ANDROID_PLAY_INTEGRITY_FAILED"


# ==============================================================================
# 3. VIO / ICP-Brasil X.509, CMS PKCS#7, P1363<->DER, Anti-Cloning & Zip-Bomb
# ==============================================================================


def test_ecdsa_p256_ieee_p1363_and_der_roundtrip_and_cms_vio_qr_pipeline() -> None:
    _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
    validator = GovCryptographicDocumentValidator(trusted_roots=[root_cert])

    sample_msg = b"SENATRAN-VIO-SIGNED-PAYLOAD"
    der_sig = leaf_key.sign(sample_msg, ec.ECDSA(hashes.SHA256()))
    raw_rs = der_to_ieee_p1363_signature(der_sig, coord_size=32)
    assert len(raw_rs) == 64
    re_der = ieee_p1363_to_der_signature(raw_rs, coord_size=32)
    leaf_cert.public_key().verify(re_der, sample_msg, ec.ECDSA(hashes.SHA256()))  # type: ignore[union-attr]

    with pytest.raises(ValueError, match="Assinatura IEEE P1363 inválida"):
        ieee_p1363_to_der_signature(b"\x01" * 30, coord_size=32)

    vio_json = json.dumps(
        {
            "cpf": VALID_CPF_A,
            "nome": "WAGNER OLIVEIRA CLAUDIANO",
            "renach": "SP123456789",
        }
    ).encode("utf-8")
    cms_der = _build_cms_signed_data_der(
        payload_bytes=vio_json,
        signer_key=leaf_key,
        signer_cert=leaf_cert,
        use_signed_attrs=True,
        use_ieee_p1363_ecdsa=True,
    )
    qr_png = _render_vio_qr_png(cms_der, low_contrast_small=True)

    res_ok = validator.validate_vio_qr_crop(
        qr_png, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert res_ok.valid is True
    assert res_ok.signature_valid is True
    assert res_ok.cert_chain_valid is True
    assert res_ok.cloning_detected is False
    assert res_ok.extracted_cpf == VALID_CPF_A


def test_vio_cnh_cloning_tampered_cms_untrusted_root_and_expired_cert_rejected() -> None:
    _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
    validator = GovCryptographicDocumentValidator(trusted_roots=[root_cert])
    vio_json = json.dumps({"cpf": VALID_CPF_A, "nome": "WAGNER OLIVEIRA"}).encode("utf-8")

    # Genuine CMS signed for CPF_A, but presented on CPF_B's CNH -> Cloning detected!
    cms_valid = _build_cms_signed_data_der(
        payload_bytes=vio_json, signer_key=leaf_key, signer_cert=leaf_cert
    )
    cloned = validator.validate_vio_payload_bytes(
        cms_valid, ocr_cpf=VALID_CPF_B, typed_cpf=VALID_CPF_B
    )
    assert not cloned.valid
    assert cloned.signature_valid is True
    assert cloned.cloning_detected is True
    assert cloned.reason_code == "VIO_CPF_CLONING_MISMATCH"

    # Tampered encapsulated payload after signing -> CMS_MESSAGE_DIGEST_MISMATCH
    cms_tampered_payload = _build_cms_signed_data_der(
        payload_bytes=vio_json,
        signer_key=leaf_key,
        signer_cert=leaf_cert,
        tamper_encap_after_sign=True,
    )
    res_digest_err = validator.validate_vio_payload_bytes(
        cms_tampered_payload, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert not res_digest_err.valid
    assert res_digest_err.reason_code == "CMS_MESSAGE_DIGEST_MISMATCH"

    # Tampered signature bytes -> CMS_SIGNATURE_INVALID
    cms_tampered_sig = _build_cms_signed_data_der(
        payload_bytes=vio_json,
        signer_key=leaf_key,
        signer_cert=leaf_cert,
        tamper_signature_after_sign=True,
    )
    res_sig_err = validator.validate_vio_payload_bytes(
        cms_tampered_sig, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert not res_sig_err.valid
    assert res_sig_err.reason_code == "CMS_SIGNATURE_INVALID"

    # Untrusted Rogue Root CA -> X509_TRUST_CHAIN_INVALID
    _, _, rogue_leaf_key, rogue_leaf_cert = _generate_ecdsa_pki_hierarchy()
    rogue_cms = _build_cms_signed_data_der(
        payload_bytes=vio_json, signer_key=rogue_leaf_key, signer_cert=rogue_leaf_cert
    )
    res_rogue = validator.validate_vio_payload_bytes(
        rogue_cms, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert not res_rogue.valid and res_rogue.reason_code == "X509_TRUST_CHAIN_INVALID"

    # Expired Issuer Certificate -> X509_TRUST_CHAIN_INVALID
    _, exp_root, exp_leaf_key, exp_leaf_cert = _generate_ecdsa_pki_hierarchy(
        expired_leaf=True
    )
    exp_val = GovCryptographicDocumentValidator(trusted_roots=[exp_root])
    exp_cms = _build_cms_signed_data_der(
        payload_bytes=vio_json, signer_key=exp_leaf_key, signer_cert=exp_leaf_cert
    )
    res_exp = exp_val.validate_vio_payload_bytes(
        exp_cms, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert not res_exp.valid and not res_exp.cert_chain_valid


def test_rsa_2048_pkcs1v15_and_pss_compact_envelope_and_zip_bomb_defense() -> None:
    _, rsa_root, rsa_leaf_key, rsa_leaf_cert = _generate_rsa_pki_hierarchy()
    validator = GovCryptographicDocumentValidator(
        trusted_roots=[rsa_root], max_decompressed_bytes=65536
    )

    vio_payload = json.dumps({"cpf": VALID_CPF_A, "nome": "WAGNER OLIVEIRA"}).encode(
        "utf-8"
    )
    # Direct CMS without signed_attrs (RSA PKCS#1 v1.5)
    cms_pkcs1 = _build_cms_signed_data_der(
        payload_bytes=vio_payload,
        signer_key=rsa_leaf_key,
        signer_cert=rsa_leaf_cert,
        use_signed_attrs=False,
        use_rsa_pss=False,
    )
    assert validator.validate_vio_payload_bytes(
        cms_pkcs1, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    ).valid

    # CMS with RSA-PSS
    cms_pss = _build_cms_signed_data_der(
        payload_bytes=vio_payload,
        signer_key=rsa_leaf_key,
        signer_cert=rsa_leaf_cert,
        use_rsa_pss=True,
    )
    assert validator.validate_vio_payload_bytes(
        cms_pss, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    ).valid

    # Compact VIO JSON Envelope (ES256 raw P1363)
    _, ec_root, ec_leaf_key, ec_leaf_cert = _generate_ecdsa_pki_hierarchy()
    validator.add_trusted_root(ec_root)
    compressed_inner = zlib.compress(vio_payload, level=9)
    raw_p1363_sig = der_to_ieee_p1363_signature(
        ec_leaf_key.sign(compressed_inner, ec.ECDSA(hashes.SHA256())), coord_size=32
    )
    compact_env = json.dumps(
        {
            "alg": "ES256",
            "cert_der_b64": base64.b64encode(
                ec_leaf_cert.public_bytes(serialization.Encoding.DER)
            ).decode("ascii"),
            "payload_b64": base64.b64encode(compressed_inner).decode("ascii"),
            "signature_b64": base64.b64encode(raw_p1363_sig).decode("ascii"),
        }
    ).encode("utf-8")
    assert validator.validate_vio_payload_bytes(
        compact_env, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    ).valid

    # Zlib Zip-Bomb Attack: 8 MiB payload compressed into ~8 KiB stream
    zip_bomb_compressed = zlib.compress(b"A" * (8 * 1024 * 1024), level=9)
    assert len(zip_bomb_compressed) < 16384
    with pytest.raises(ZipBombDetectedError):
        validator.safe_zlib_decompress(zip_bomb_compressed)

    bomb_res = validator.validate_vio_payload_bytes(
        zip_bomb_compressed, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert bomb_res.valid is False
    assert bomb_res.zip_bomb_blocked is True
    assert bomb_res.reason_code == "VIO_ZIP_BOMB_BLOCKED"


# ==============================================================================
# 4. ICAO Doc 9303 NFC Passive Authentication (EF.SOD + DG1 + DG2)
# ==============================================================================


def test_icao_9303_nfc_passive_authentication_intact_vs_tampered_dg1_dg2_and_csca() -> None:
    _, csca_root, ds_key, ds_cert = _generate_ecdsa_pki_hierarchy()
    validator = GovCryptographicDocumentValidator(trusted_roots=[csca_root])

    dg1_mrz_bytes = b"IDBRA1234567897<<<<<<<<<<<<<<<9001018M3201017BRA<<<<<<<<<<<6OLIVEIRA<<WAGNER<<<<<<<<<<<<<<"
    dg2_face_iso19794_bytes = (
        b"FAC\x00010\x00" + b"\xff\xd8\xff\xe0CANONICAL_CHIP_FACE_JPEG\xff\xd9"
    )

    lds_so = LDSSecurityObject(
        {
            "version": 0,
            "hash_algorithm": {"algorithm": "2.16.840.1.101.3.4.2.1"},
            "data_group_hash_values": DataGroupHashValues(
                [
                    DataGroupHash(
                        {
                            "data_group_number": 1,
                            "data_group_hash_value": hashlib.sha256(dg1_mrz_bytes).digest(),
                        }
                    ),
                    DataGroupHash(
                        {
                            "data_group_number": 2,
                            "data_group_hash_value": hashlib.sha256(
                                dg2_face_iso19794_bytes
                            ).digest(),
                        }
                    ),
                ]
            ),
        }
    )
    cms_sod = _build_cms_signed_data_der(
        payload_bytes=lds_so.dump(),
        signer_key=ds_key,
        signer_cert=ds_cert,
        use_signed_attrs=True,
    )
    ef_sod_der = _wrap_icao_tag_77(cms_sod)

    # 1. Intact chip data groups -> Valid
    nfc_ok = validator.validate_nfc_passive_auth(
        ef_sod_der, dg1_mrz_bytes, dg2_face_iso19794_bytes
    )
    assert nfc_ok.valid is True
    assert nfc_ok.dg1_hash_matched is True
    assert nfc_ok.dg2_hash_matched is True

    # 2. Tampered DG2 face biometric portrait -> NFC_DG2_FACE_HASH_MISMATCH
    tampered_dg2 = dg2_face_iso19794_bytes[:-4] + b"FAKE"
    nfc_bad_dg2 = validator.validate_nfc_passive_auth(
        ef_sod_der, dg1_mrz_bytes, tampered_dg2
    )
    assert not nfc_bad_dg2.valid
    assert nfc_bad_dg2.reason_code == "NFC_DG2_FACE_HASH_MISMATCH"

    # 3. Tampered DG1 MRZ -> NFC_DG1_MRZ_HASH_MISMATCH
    tampered_dg1 = b"X" + dg1_mrz_bytes[1:]
    nfc_bad_dg1 = validator.validate_nfc_passive_auth(
        ef_sod_der, tampered_dg1, dg2_face_iso19794_bytes
    )
    assert not nfc_bad_dg1.valid
    assert nfc_bad_dg1.reason_code == "NFC_DG1_MRZ_HASH_MISMATCH"

    # 4. Untrusted CSCA Root -> NFC_X509_TRUST_CHAIN_INVALID
    empty_validator = GovCryptographicDocumentValidator(trusted_roots=[])
    nfc_untrusted = empty_validator.validate_nfc_passive_auth(
        ef_sod_der, dg1_mrz_bytes, dg2_face_iso19794_bytes
    )
    assert not nfc_untrusted.valid
    assert nfc_untrusted.reason_code == "NFC_X509_TRUST_CHAIN_INVALID"


# ==============================================================================
# 5. SERPRO Datavalid mTLS: TLS 1.3 SSLContext, OAuth2 Lock & Circuit Breaker
# ==============================================================================


def test_serpro_mtls_tls13_oauth2_concurrency_circuit_breaker_and_irregular_cpf() -> None:
    async def _run_scenario() -> None:
        # Homologation transparent mode without external mTLS credentials
        homolog_client = SerproDatavalidMtlsClient(
            KYCZeroTrustSettings(environment="homologation")
        )
        try:
            homolog_res = await homolog_client.validate_pf_facial_biometrics(
                cpf_digits=VALID_CPF_A, canonical_selfie_bytes=b"selfie"
            )
            assert homolog_res.passed is True
            assert homolog_res.mode == "HOMOLOGATION_LOCAL"
        finally:
            await homolog_client.close()

        now_clock = [1000.0]
        token_calls = 0
        response_mode = "ok"

        async def mock_handler(request: httpx.Request) -> httpx.Response:
            nonlocal token_calls
            if request.url.path.endswith("/token"):
                token_calls += 1
                await asyncio.sleep(0.01)
                return httpx.Response(
                    200, json={"access_token": "serpro-tok-1", "expires_in": 3600}
                )
            if response_mode == "fail_503":
                return httpx.Response(503, json={"error": "Service Unavailable"})
            if response_mode == "irregular_cpf":
                return httpx.Response(
                    200,
                    json={
                        "situacao_cpf": "suspensa",
                        "biometria_face": {"similaridade": 0.96},
                    },
                )
            return httpx.Response(
                200,
                json={
                    "cpf_disponivel": True,
                    "situacao_cpf": "regular",
                    "biometria_face": {"similaridade": 94.0},  # 0..100 percentage normalized to 0.94
                },
            )

        cfg = KYCZeroTrustSettings(
            environment="homologation",
            serpro_consumer_key="ck",
            serpro_consumer_secret="cs",
            serpro_cb_failure_threshold=3,
            serpro_cb_recovery_timeout_seconds=30.0,
        )
        client = SerproDatavalidMtlsClient(
            cfg,
            transport=httpx.MockTransport(mock_handler),
            clock_fn=lambda: now_clock[0],
        )
        try:
            assert client.ssl_context.minimum_version == ssl.TLSVersion.TLSv1_3
            assert client.ssl_context.verify_mode == ssl.CERT_REQUIRED

            # 10 concurrent calls -> exactly 1 OAuth2 token request
            results = await asyncio.gather(
                *[
                    client.validate_pf_facial_biometrics(
                        cpf_digits=VALID_CPF_A,
                        canonical_selfie_bytes=b"selfie-jpeg",
                    )
                    for _ in range(10)
                ]
            )
            assert token_calls == 1
            assert all(r.passed and r.similarity == 0.94 for r in results)

            # Irregular CPF -> passed=False
            response_mode = "irregular_cpf"
            irr = await client.validate_pf_facial_biometrics(
                cpf_digits=VALID_CPF_A, canonical_selfie_bytes=b"selfie-jpeg"
            )
            assert not irr.passed and irr.reason_code == "SERPRO_CPF_IRREGULAR"

            # Trip Circuit Breaker: CLOSED -> OPEN
            response_mode = "fail_503"
            for _ in range(3):
                with pytest.raises(httpx.HTTPStatusError):
                    await client.validate_pf_facial_biometrics(
                        cpf_digits=VALID_CPF_A, canonical_selfie_bytes=b"selfie-jpeg"
                    )
            assert client.circuit_state == CircuitState.OPEN
            with pytest.raises(SerproCircuitOpenError):
                await client.validate_pf_facial_biometrics(
                    cpf_digits=VALID_CPF_A, canonical_selfie_bytes=b"selfie-jpeg"
                )

            # Recovery: OPEN -> HALF_OPEN -> CLOSED
            now_clock[0] += 35.0
            assert client.circuit_state == CircuitState.HALF_OPEN
            response_mode = "ok"
            recovered = await client.validate_pf_facial_biometrics(
                cpf_digits=VALID_CPF_A, canonical_selfie_bytes=b"selfie-jpeg"
            )
            assert recovered.passed is True
            assert client.circuit_state == CircuitState.CLOSED
        finally:
            await client.close()

    asyncio.run(_run_scenario())


# ==============================================================================
# 6. CarbonFraudOrchestrator: All 5 Pre-LLM Hard Vetos, Contingency & Alcada
# ==============================================================================


def test_carbon_fraud_orchestrator_enforces_all_5_hard_vetos_and_contingency() -> None:
    async def _run_vetos() -> None:
        cfg = KYCZeroTrustSettings(environment="homologation")
        sec = ZeroTrustSecurityEngine(cfg)
        llm_invocations = 0

        def rogue_llm(_summary: dict) -> _CarbonLLMCorrelationSchema:
            nonlocal llm_invocations
            llm_invocations += 1
            return _CarbonLLMCorrelationSchema(
                recommended_status="APPROVED",
                confidence_score=0.99,
                risk_tier="LOW",
                shap_top_3_factors=["Fator 1", "Fator 2", "Fator 3"],
                user_friendly_message_ptbr="Aprovado via ASN.1 PKCS#7 e SHAP mTLS Mod 11!",
            )

        orch = CarbonFraudOrchestrator(cfg, sec, llm_responder=rogue_llm)

        _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
        crypto_val = GovCryptographicDocumentValidator(trusted_roots=[root_cert])
        valid_cms = _build_cms_signed_data_der(
            payload_bytes=json.dumps({"cpf": VALID_CPF_A}).encode("utf-8"),
            signer_key=leaf_key,
            signer_cert=leaf_cert,
        )
        valid_vio = crypto_val.validate_vio_payload_bytes(
            valid_cms, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
        )
        valid_serpro = SerproBiometricResult(
            passed=True,
            similarity=0.96,
            cpf_regular=True,
            active_external_mtls=True,
            mode="SERPRO_MTLS_LIVE",
            circuit_state=CircuitState.CLOSED,
            reason_code="OK",
        )

        t0 = 1_762_950_000
        ch = sec.issue_anti_swap_session_token("u-1", now_ts=t0)
        sh, fh, bh = sec.sha256_hex(b"s"), sec.sha256_hex(b"f"), sec.sha256_hex(b"b")
        rh = sec.compute_anti_swap_request_hash("u-1", ch.session_nonce, sh, fh, bh)
        valid_anti_swap = sec.verify_anti_swap_and_device_integrity(
            user_id="u-1",
            session_nonce=ch.session_nonce,
            session_issued_at=ch.issued_at,
            session_signature=ch.session_signature,
            liveness_timestamp=t0 + 10,
            doc_capture_timestamp=t0 + 25,
            selfie_hash=sh,
            doc_front_hash=fh,
            doc_back_hash=bh,
            request_hash=rh,
            now_ts=t0 + 30,
        )

        # VETO 1: Anti-Swap
        v1 = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.98,
            local_face_match_score=0.95,
            anti_swap_result=valid_anti_swap.model_copy(
                update={"valid": False, "reason_code": "VIRTUAL_CAMERA_SUSPECTED"}
            ),
            argon_artifacts=_make_clean_argon_artifacts(),
            vio_result=valid_vio,
            serpro_result=valid_serpro,
        )
        assert v1.status == "REJECTED" and v1.hard_veto_triggered

        # VETO 2: Prompt Injection, Screen Replay & Low Liveness
        for kwargs_art, l_score, expected_code in [
            ({"is_readable": False, "prompt_injection": True}, 0.98, "VETO_2_PROMPT_INJECTION_DETECTED"),
            ({"is_readable": False, "screen_replay": True}, 0.98, "VETO_2_SCREEN_REPLAY_OR_TAMPERING"),
            ({}, 0.89, "VETO_2_LIVENESS_BELOW_THRESHOLD"),
        ]:
            v2 = await orch.evaluate_kyc_dossier(
                user_id="u-1",
                typed_cpf=VALID_CPF_A,
                typed_full_name="Wagner Oliveira",
                canonical_selfie_bytes=b"s",
                liveness_score=l_score,
                local_face_match_score=0.95,
                anti_swap_result=valid_anti_swap,
                argon_artifacts=_make_clean_argon_artifacts(**kwargs_art),
                vio_result=valid_vio,
                serpro_result=valid_serpro,
            )
            assert v2.status == "REJECTED" and v2.hard_veto_code == expected_code

        # VETO 3: Invalid Mod-11 CPF, MRZ Checksum & Name Mismatch
        v3_cpf = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf="11111111111",
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.95,
            anti_swap_result=valid_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(),
            vio_result=valid_vio,
            serpro_result=valid_serpro,
        )
        assert v3_cpf.status == "REJECTED" and v3_cpf.hard_veto_code == "VETO_3_CPF_MOD11_INVALID"

        v3_mrz = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.95,
            anti_swap_result=valid_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(mrz_valid=False),
            vio_result=valid_vio,
            serpro_result=valid_serpro,
        )
        assert v3_mrz.status == "REJECTED" and v3_mrz.hard_veto_code == "VETO_3_MRZ_CHECKSUM_INVALID"

        # VETO 4: Missing VIO on CNH & Cloned VIO CPF
        v4_missing = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.95,
            anti_swap_result=valid_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(doc_type="CNH"),
            vio_result=None,
            serpro_result=valid_serpro,
        )
        assert v4_missing.status == "REJECTED" and v4_missing.hard_veto_code == "VETO_4_VIO_QR_MISSING"

        # VETO 5: Local Face Match < 0.88
        v5_local = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.81,
            anti_swap_result=valid_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(),
            vio_result=valid_vio,
            serpro_result=valid_serpro,
        )
        assert v5_local.status == "REJECTED" and v5_local.hard_veto_code == "VETO_5_LOCAL_FACE_MISMATCH"

        # SERPRO Circuit Open Contingency -> MANUAL_REVIEW without calling LLM!
        contingency = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.94,
            anti_swap_result=valid_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(),
            vio_result=valid_vio,
            serpro_result=None,
            serpro_unavailable=True,
        )
        assert contingency.status == "MANUAL_REVIEW"
        assert llm_invocations == 0

        # Web PWA approval preserves WEB_LIMITED_ALCADA even if LLM returns risk_tier='LOW'
        web_anti_swap = valid_anti_swap.model_copy(
            update={"alcada_restriction": "WEB_LIMITED_ALCADA"}
        )
        web_ok = await orch.evaluate_kyc_dossier(
            user_id="u-1",
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira",
            canonical_selfie_bytes=b"s",
            liveness_score=0.97,
            local_face_match_score=0.95,
            anti_swap_result=web_anti_swap,
            argon_artifacts=_make_clean_argon_artifacts(),
            vio_result=valid_vio,
            serpro_result=valid_serpro,
        )
        assert llm_invocations == 1
        assert web_ok.status == "APPROVED"
        assert web_ok.alcada_restriction == "WEB_LIMITED_ALCADA"
        assert web_ok.risk_tier == "MEDIUM"
        assert "ASN.1" not in web_ok.user_friendly_message_ptbr

        natural = "O envio da sua foto em boa camada de luz foi concluído com sucesso!"
        assert sanitize_human_message_ptbr(natural, "APPROVED") == natural

    asyncio.run(_run_vetos())


# ==============================================================================
# 7. FastAPI Gateway End-to-End & Signed Supabase Webhook Verification
# ==============================================================================


def test_fastapi_gateway_full_kyc_attacks_smart_split_and_webhook_hmac() -> None:
    cfg = KYCZeroTrustSettings(environment="homologation")
    sec = ZeroTrustSecurityEngine(cfg)
    _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
    crypto_val = GovCryptographicDocumentValidator(trusted_roots=[root_cert])

    captured_webhooks: list[tuple[str, bytes, dict[str, str]]] = []

    async def fake_webhook_dispatcher(
        url: str, raw_body: bytes, headers: dict[str, str]
    ) -> int:
        captured_webhooks.append((url, raw_body, headers))
        return 200

    test_app = create_kyc_app(
        settings=cfg,
        security_engine=sec,
        crypto_validator=crypto_val,
        webhook_dispatcher=fake_webhook_dispatcher,
    )

    with TestClient(test_app) as client:
        assert client.get("/healthz").status_code == 200
        assert client.post("/v1/kyc/session/init", json={}).status_code == 422

        # Form-encoded session init also supported alongside JSON
        user_uuid = "550e8400-e29b-41d4-a716-446655440000"
        t0 = int(datetime.now(timezone.utc).timestamp())
        init_form = client.post(
            "/v1/kyc/session/init", data={"user_id": user_uuid, "now_ts": str(t0)}
        )
        assert init_form.status_code == 200
        challenge = init_form.json()

        selfie_bytes = _make_jpeg_bytes(400, 400, (220, 200, 190))
        front_bytes = _make_jpeg_bytes(900, 600, (245, 245, 240))
        back_bytes = _make_jpeg_bytes(900, 600, (240, 245, 245))
        cms_der = _build_cms_signed_data_der(
            payload_bytes=json.dumps(
                {"cpf": VALID_CPF_A, "nome": "WAGNER OLIVEIRA CLAUDIANO"}
            ).encode("utf-8"),
            signer_key=leaf_key,
            signer_cert=leaf_cert,
        )
        qr_png = _render_vio_qr_png(cms_der)
        req_hash = sec.compute_anti_swap_request_hash(
            user_uuid,
            challenge["session_nonce"],
            sec.sha256_hex(selfie_bytes),
            sec.sha256_hex(front_bytes),
            sec.sha256_hex(back_bytes),
        )

        # 1. Legitimate Full KYC -> APPROVED + Signed Webhook
        verify_resp = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_uuid,
                "typed_cpf": VALID_CPF_A,
                "typed_full_name": "Wagner Oliveira",
                "session_nonce": challenge["session_nonce"],
                "session_issued_at": str(challenge["issued_at"]),
                "session_signature": challenge["session_signature"],
                "liveness_timestamp": str(t0 + 15),
                "doc_capture_timestamp": str(t0 + 35),
                "request_hash": req_hash,
                "liveness_score": "0.97",
                "local_face_match_score": "0.94",
                "capture_source": "LIVE_CAMERA",
                "platform": "ANDROID",
                "attestation_verdict": "MEETS_STRONG_INTEGRITY",
                "now_ts_override": str(t0 + 40),
            },
            files={
                "selfie_liveness": ("selfie.jpg", selfie_bytes, "image/jpeg"),
                "doc_front": ("front.jpg", front_bytes, "image/jpeg"),
                "doc_back": ("back.jpg", back_bytes, "image/jpeg"),
                "vio_qr_crop_override": ("vio_qr.png", qr_png, "image/png"),
            },
        )
        assert verify_resp.status_code == 200, verify_resp.text
        body = verify_resp.json()
        assert body["verdict"]["status"] == "APPROVED"
        assert body["webhook_dispatched"] is True

        _, raw_wh_bytes, wh_headers = captured_webhooks[0]
        wh_ts = int(wh_headers["X-KYC-Timestamp"])
        wh_sig = wh_headers["X-KYC-Signature"]
        assert sec.verify_supabase_webhook(raw_wh_bytes, wh_ts, wh_sig, now_ts=wh_ts + 5)
        assert not sec.verify_supabase_webhook(raw_wh_bytes, wh_ts, wh_sig, now_ts=wh_ts + 301)
        assert VALID_CPF_A.encode("utf-8") not in raw_wh_bytes

        # 2. Cloned CNH Attack via HTTP Gateway -> REJECTED (VETO_4_VIO_CPF_CLONING_DETECTED)
        ch2 = client.post(
            "/v1/kyc/session/init", json={"user_id": user_uuid, "now_ts": t0}
        ).json()
        rh2 = sec.compute_anti_swap_request_hash(
            user_uuid,
            ch2["session_nonce"],
            sec.sha256_hex(selfie_bytes),
            sec.sha256_hex(front_bytes),
            sec.sha256_hex(back_bytes),
        )
        clone_resp = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_uuid,
                "typed_cpf": VALID_CPF_B,
                "typed_full_name": "Wagner Oliveira",
                "session_nonce": ch2["session_nonce"],
                "session_issued_at": str(ch2["issued_at"]),
                "session_signature": ch2["session_signature"],
                "liveness_timestamp": str(t0 + 10),
                "doc_capture_timestamp": str(t0 + 25),
                "request_hash": rh2,
                "liveness_score": "0.97",
                "local_face_match_score": "0.94",
                "now_ts_override": str(t0 + 30),
            },
            files={
                "selfie_liveness": ("selfie.jpg", selfie_bytes, "image/jpeg"),
                "doc_front": ("front.jpg", front_bytes, "image/jpeg"),
                "doc_back": ("back.jpg", back_bytes, "image/jpeg"),
                "vio_qr_crop_override": ("vio_qr.png", qr_png, "image/png"),
            },
        )
        assert clone_resp.status_code == 200
        assert clone_resp.json()["verdict"]["status"] == "REJECTED"
        assert (
            clone_resp.json()["verdict"]["hard_veto_code"]
            == "VETO_4_VIO_CPF_CLONING_DETECTED"
        )

        # 3. Smart Split Legitimate vs Prompt-Injected Invoice
        ok_inv = client.post(
            "/v1/smart-split/verify-invoice",
            data={"user_id": user_uuid, "declared_materials_cents": "18500"},
            files={"invoice_image": ("danfe.jpg", _make_jpeg_bytes(), "image/jpeg")},
        )
        assert ok_inv.status_code == 200 and ok_inv.json()["approved"] is True


# ==============================================================================
# 6. Red-Team Regression Suite (#11): Production Guards, NaN/Inf, CNH/VIO & RFC5280
# ==============================================================================


def test_production_http_guards_clock_override_vio_bypass_and_413_upload_ceiling() -> None:
    import time as time_mod

    prod_cfg = KYCZeroTrustSettings(
        environment="production",
        master_kek_hex="a1" * 32,
        cpf_pepper_secret="prod-pepper-secret-2026",
        session_hmac_secret="prod-session-hmac-secret-2026",
        supabase_webhook_secret="prod-supabase-wh-secret-2026",
        supabase_webhook_url="https://prod.supabase.co/functions/v1/kyc-carbon-webhook",
        gemini_api_key="prod-gemini-key-placeholder",
    )
    assert prod_cfg.is_production is True

    sec = ZeroTrustSecurityEngine(prod_cfg)
    _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
    crypto_val = GovCryptographicDocumentValidator(trusted_roots=[root_cert])

    async def _mock_serpro_handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/token"):
            return httpx.Response(
                200, json={"access_token": "prod-tok", "expires_in": 3600}
            )
        return httpx.Response(
            200, json={"similaridade": 0.96, "situacao_cpf": "regular"}
        )

    prod_serpro = SerproDatavalidMtlsClient(
        prod_cfg, transport=httpx.MockTransport(_mock_serpro_handler)
    )

    class _DeterministicProdVisionStub:
        async def extract_and_ground_document(
            self,
            *,
            front_jpeg_bytes: bytes,
            back_jpeg_bytes: bytes,
            user_typed_cpf: str,
            user_typed_name: str,
        ) -> ArgonProcessedArtifacts:
            clean_cpf = "".join(ch for ch in user_typed_cpf if ch.isdigit())
            return ArgonProcessedArtifacts(
                dossier=ExtractedDocumentDossierArgon(
                    quality_gate=OpticalForensicsAndQualityGate(
                        is_readable=True,
                        canonical_rotation_deg=0,
                        is_full_document_visible=True,
                        has_glare_on_critical_zones=False,
                        is_screen_replay_or_moire_suspected=False,
                        has_portrait_paste_or_font_tampering=False,
                        adversarial_prompt_injection_detected=False,
                        detected_document_type="CNH",
                    ),
                    spatial_rois=SpatialRegionsOfInterest(),
                    full_civil_name=user_typed_name.strip().upper(),
                    cpf_11_digits=clean_cpf,
                    front_back_cpf_consistent=True,
                    cpf_mod11_valid=True,
                ),
                cropped_portrait_3x4_jpeg=front_jpeg_bytes,
                cropped_qr_code_vio_png=back_jpeg_bytes,
                canonical_front_jpeg=front_jpeg_bytes,
                canonical_back_jpeg=back_jpeg_bytes,
                ready_for_serpro_and_carbon=True,
                name_compatibility_score=1.0,
            )

        async def analyze_fiscal_invoice_argon(
            self, *, invoice_image_bytes: bytes, declared_materials_cents: int
        ):
            raise AssertionError("Should be blocked by 413 before vision call")

    prod_orch = CarbonFraudOrchestrator(
        prod_cfg,
        sec,
        genai_client=object(),
        llm_responder=lambda _: _CarbonLLMCorrelationSchema(
            recommended_status="APPROVED",
            confidence_score=0.97,
            risk_tier="LOW",
            shap_top_3_factors=[
                "Integridade de produção validada.",
                "Selo criptográfico conferido.",
                "Biometria consistente.",
            ],
            user_friendly_message_ptbr="Identidade confirmada com sucesso.",
        ),
    )

    async def _noop_webhook(_url: str, _raw: bytes, _headers: dict) -> int:
        return 200

    app = create_kyc_app(
        settings=prod_cfg,
        security_engine=sec,
        crypto_validator=crypto_val,
        serpro_client=prod_serpro,
        vision_service=_DeterministicProdVisionStub(),
        fraud_orchestrator=prod_orch,
        webhook_dispatcher=_noop_webhook,
    )

    user_uuid = "99999999-8888-4777-8666-555555555555"
    with TestClient(app) as client:
        # 1. Production POST /v1/kyc/session/init MUST ignore client-supplied now_ts (JSON & Form)
        real_now = int(time_mod.time())
        spoofed_future = real_now + 999_999
        init_json = client.post(
            "/v1/kyc/session/init",
            json={"user_id": user_uuid, "now_ts": spoofed_future},
        )
        assert init_json.status_code == 200
        ch = init_json.json()
        assert abs(ch["issued_at"] - real_now) <= 5

        init_form = client.post(
            "/v1/kyc/session/init",
            data={"user_id": user_uuid, "now_ts": str(spoofed_future)},
        )
        assert init_form.status_code == 200
        assert abs(init_form.json()["issued_at"] - int(time_mod.time())) <= 5

        # 2. Production POST /v1/kyc/verify-full MUST ignore now_ts_override on expired token
        expired_t0 = int(time_mod.time()) - 500
        expired_ch = sec.issue_anti_swap_session_token(user_uuid, now_ts=expired_t0)
        selfie_bytes = _make_jpeg_bytes(400, 400)
        front_bytes = _make_jpeg_bytes(800, 500)
        back_without_qr = _make_jpeg_bytes(800, 500)
        expired_rh = sec.compute_anti_swap_request_hash(
            user_uuid,
            expired_ch.session_nonce,
            sec.sha256_hex(selfie_bytes),
            sec.sha256_hex(front_bytes),
            sec.sha256_hex(back_without_qr),
        )
        expired_resp = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_uuid,
                "typed_cpf": VALID_CPF_A,
                "typed_full_name": "Wagner Oliveira",
                "session_nonce": expired_ch.session_nonce,
                "session_issued_at": str(expired_ch.issued_at),
                "session_signature": expired_ch.session_signature,
                "liveness_timestamp": str(expired_t0 + 10),
                "doc_capture_timestamp": str(expired_t0 + 25),
                "request_hash": expired_rh,
                "liveness_score": "0.97",
                "local_face_match_score": "0.94",
                "now_ts_override": str(expired_t0 + 30),
            },
            files={
                "selfie_liveness": ("selfie.jpg", selfie_bytes, "image/jpeg"),
                "doc_front": ("front.jpg", front_bytes, "image/jpeg"),
                "doc_back": ("back.jpg", back_without_qr, "image/jpeg"),
            },
        )
        assert expired_resp.status_code == 200
        assert expired_resp.json()["verdict"]["status"] == "REJECTED"
        assert (
            expired_resp.json()["verdict"]["hard_veto_code"]
            == "VETO_1_ANTI_SWAP_SESSION_TTL_EXPIRED"
        )

        # 3. Production POST /v1/kyc/verify-full MUST force require_vio_for_modern_docs=True
        #    AND ignore unbound vio_qr_crop_override!
        cms_der = _build_cms_signed_data_der(
            payload_bytes=json.dumps(
                {"cpf": VALID_CPF_A, "name": "WAGNER OLIVEIRA"}
            ).encode("utf-8"),
            signer_key=leaf_key,
            signer_cert=leaf_cert,
        )
        valid_qr_png = _render_vio_qr_png(cms_der)
        live_now = int(time_mod.time())
        live_ch = client.post(
            "/v1/kyc/session/init", json={"user_id": user_uuid}
        ).json()
        live_rh = sec.compute_anti_swap_request_hash(
            user_uuid,
            live_ch["session_nonce"],
            sec.sha256_hex(selfie_bytes),
            sec.sha256_hex(front_bytes),
            sec.sha256_hex(back_without_qr),
        )
        bypass_attempt = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_uuid,
                "typed_cpf": VALID_CPF_A,
                "typed_full_name": "Wagner Oliveira",
                "session_nonce": live_ch["session_nonce"],
                "session_issued_at": str(live_ch["issued_at"]),
                "session_signature": live_ch["session_signature"],
                "liveness_timestamp": str(max(live_ch["issued_at"], live_now)),
                "doc_capture_timestamp": str(max(live_ch["issued_at"], live_now)),
                "request_hash": live_rh,
                "liveness_score": "0.97",
                "local_face_match_score": "0.94",
                "require_vio_for_modern_docs": "false",
            },
            files={
                "selfie_liveness": ("selfie.jpg", selfie_bytes, "image/jpeg"),
                "doc_front": ("front.jpg", front_bytes, "image/jpeg"),
                "doc_back": ("back.jpg", back_without_qr, "image/jpeg"),
                "vio_qr_crop_override": ("vio_qr.png", valid_qr_png, "image/png"),
            },
        )
        assert bypass_attempt.status_code == 200
        bypass_verdict = bypass_attempt.json()["verdict"]
        assert bypass_verdict["status"] == "REJECTED"
        assert bypass_verdict["hard_veto_triggered"] is True
        assert bypass_verdict["hard_veto_code"].startswith("VETO_4_VIO_")

        # 4. Bounded 15 MiB upload ceiling -> HTTP 413 on oversized files (anti-OOM DoS)
        oversized_blob = b"\xff\xd8\xff\xe0" + (b"\x00" * (15 * 1024 * 1024 + 64))
        too_large_kyc = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_uuid,
                "typed_cpf": VALID_CPF_A,
                "typed_full_name": "Wagner Oliveira",
                "session_nonce": live_ch["session_nonce"],
                "session_issued_at": str(live_ch["issued_at"]),
                "session_signature": live_ch["session_signature"],
                "liveness_timestamp": str(live_ch["issued_at"]),
                "doc_capture_timestamp": str(live_ch["issued_at"]),
                "request_hash": live_rh,
                "liveness_score": "0.97",
                "local_face_match_score": "0.94",
            },
            files={
                "selfie_liveness": ("huge.jpg", oversized_blob, "image/jpeg"),
                "doc_front": ("front.jpg", front_bytes, "image/jpeg"),
                "doc_back": ("back.jpg", back_without_qr, "image/jpeg"),
            },
        )
        assert too_large_kyc.status_code == 413

        too_large_inv = client.post(
            "/v1/smart-split/verify-invoice",
            data={"user_id": user_uuid, "declared_materials_cents": "15000"},
            files={"invoice_image": ("huge_inv.jpg", oversized_blob, "image/jpeg")},
        )
        assert too_large_inv.status_code == 413


def test_nan_inf_biometric_bypass_cnh_codes_tier1_readiness_and_vio_name_cloning() -> None:
    cfg = KYCZeroTrustSettings(environment="homologation")
    sec = ZeroTrustSecurityEngine(cfg)
    _, root_cert, leaf_key, leaf_cert = _generate_ecdsa_pki_hierarchy()
    crypto_val = GovCryptographicDocumentValidator(trusted_roots=[root_cert])

    llm_calls = {"count": 0}

    def _never_called_llm(_payload: dict) -> _CarbonLLMCorrelationSchema:
        llm_calls["count"] += 1
        return _CarbonLLMCorrelationSchema(
            recommended_status="APPROVED",
            confidence_score=0.99,
            risk_tier="LOW",
            shap_top_3_factors=["Fator 1", "Fator 2", "Fator 3"],
            user_friendly_message_ptbr="Aprovado.",
        )

    orch = CarbonFraudOrchestrator(cfg, sec, llm_responder=_never_called_llm)
    user_id = "22222222-3333-4444-8555-666666666666"
    t0 = 1_760_600_000
    selfie = _make_jpeg_bytes(320, 320)
    sh = sec.sha256_hex(selfie)
    ch = sec.issue_anti_swap_session_token(user_id, now_ts=t0)
    rh = sec.compute_anti_swap_request_hash(user_id, ch.session_nonce, sh, sh, sh)
    valid_as = sec.verify_anti_swap_and_device_integrity(
        user_id=user_id,
        session_nonce=ch.session_nonce,
        session_issued_at=ch.issued_at,
        session_signature=ch.session_signature,
        liveness_timestamp=t0 + 10,
        doc_capture_timestamp=t0 + 20,
        selfie_hash=sh,
        doc_front_hash=sh,
        doc_back_hash=sh,
        request_hash=rh,
        capture_source="LIVE_CAMERA",
        platform="ANDROID",
        attestation_verdict="MEETS_STRONG_INTEGRITY",
        now_ts=t0 + 25,
    )

    cms_wagner = _build_cms_signed_data_der(
        payload_bytes=json.dumps(
            {"cpf": VALID_CPF_A, "name": "WAGNER OLIVEIRA CLAUDIANO"}
        ).encode("utf-8"),
        signer_key=leaf_key,
        signer_cert=leaf_cert,
    )
    vio_wagner_ok = crypto_val.validate_vio_payload_bytes(
        cms_wagner, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A
    )
    assert vio_wagner_ok.valid is True
    assert vio_wagner_ok.extracted_name == "WAGNER OLIVEIRA CLAUDIANO"

    serpro_ok = SerproBiometricResult(
        passed=True,
        similarity=0.95,
        cpf_regular=True,
        active_external_mtls=True,
        mode="SERPRO_MTLS_LIVE",
        circuit_state=CircuitState.CLOSED,
        reason_code="OK",
    )

    async def _run_checks() -> None:
        # 1. NaN / +Inf / -Inf / >1.0 on liveness_score MUST trigger VETO_2_LIVENESS_BELOW_THRESHOLD
        for bad_live in (float("nan"), float("inf"), float("-inf"), 1.5, -0.1):
            v_live = await orch.evaluate_kyc_dossier(
                user_id=user_id,
                typed_cpf=VALID_CPF_A,
                typed_full_name="Wagner Oliveira Claudiano",
                canonical_selfie_bytes=selfie,
                liveness_score=bad_live,
                local_face_match_score=0.95,
                anti_swap_result=valid_as,
                argon_artifacts=_make_clean_argon_artifacts(),
                vio_result=vio_wagner_ok,
                serpro_result=serpro_ok,
            )
            assert v_live.status == "REJECTED"
            assert v_live.hard_veto_code == "VETO_2_LIVENESS_BELOW_THRESHOLD"

        # 2. NaN / +Inf / -Inf / >1.0 on local_face_match_score MUST trigger VETO_5_LOCAL_FACE_MISMATCH
        for bad_face in (float("nan"), float("inf"), float("-inf"), 1.2, -0.2):
            v_face = await orch.evaluate_kyc_dossier(
                user_id=user_id,
                typed_cpf=VALID_CPF_A,
                typed_full_name="Wagner Oliveira Claudiano",
                canonical_selfie_bytes=selfie,
                liveness_score=0.96,
                local_face_match_score=bad_face,
                anti_swap_result=valid_as,
                argon_artifacts=_make_clean_argon_artifacts(),
                vio_result=vio_wagner_ok,
                serpro_result=serpro_ok,
            )
            assert v_face.status == "REJECTED"
            assert v_face.hard_veto_code == "VETO_5_LOCAL_FACE_MISMATCH"

        # 3. SERPRO NaN / out-of-range similarity handling
        with pytest.raises(Exception):
            SerproBiometricResult(
                passed=True,
                similarity=float("nan"),
                cpf_regular=True,
                active_external_mtls=True,
                mode="SERPRO_MTLS_LIVE",
                circuit_state=CircuitState.CLOSED,
                reason_code="OK",
            )

        responses = [
            {"similaridade": "NaN", "situacao_cpf": "regular"},
            {"similaridade": 150.0, "situacao_cpf": "regular"},
        ]

        async def _bad_serpro_handler(request: httpx.Request) -> httpx.Response:
            if request.url.path.endswith("/token"):
                return httpx.Response(
                    200, json={"access_token": "tok", "expires_in": 3600}
                )
            return httpx.Response(200, json=responses.pop(0))

        bad_serpro_client = SerproDatavalidMtlsClient(
            cfg, transport=httpx.MockTransport(_bad_serpro_handler)
        )
        try:
            r_nan = await bad_serpro_client.validate_pf_facial_biometrics(
                cpf_digits=VALID_CPF_A, canonical_selfie_bytes=selfie
            )
            assert r_nan.passed is False
            assert r_nan.similarity == 0.0
            assert r_nan.reason_code == "SERPRO_INVALID_SIMILARITY_VALUE"

            r_oob = await bad_serpro_client.validate_pf_facial_biometrics(
                cpf_digits=VALID_CPF_A, canonical_selfie_bytes=selfie
            )
            assert r_oob.passed is False
            assert r_oob.similarity == 0.0
            assert r_oob.reason_code == "SERPRO_INVALID_SIMILARITY_VALUE"
        finally:
            await bad_serpro_client.close()

        # 4. Hard Veto 3: Invalid CNH security code, invalid RENACH & unready Tier-1 dossier
        v_sec_code = await orch.evaluate_kyc_dossier(
            user_id=user_id,
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira Claudiano",
            canonical_selfie_bytes=selfie,
            liveness_score=0.96,
            local_face_match_score=0.94,
            anti_swap_result=valid_as,
            argon_artifacts=_make_clean_argon_artifacts(
                cnh_security_code_11="11111111111", ready_override=False
            ),
            vio_result=vio_wagner_ok,
            serpro_result=None,
        )
        assert v_sec_code.status == "REJECTED"
        assert v_sec_code.hard_veto_code == "VETO_3_CNH_SECURITY_CODE_INVALID"

        v_renach = await orch.evaluate_kyc_dossier(
            user_id=user_id,
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira Claudiano",
            canonical_selfie_bytes=selfie,
            liveness_score=0.96,
            local_face_match_score=0.94,
            anti_swap_result=valid_as,
            argon_artifacts=_make_clean_argon_artifacts(
                cnh_renach="12345678901", ready_override=False
            ),
            vio_result=vio_wagner_ok,
            serpro_result=None,
        )
        assert v_renach.status == "REJECTED"
        assert v_renach.hard_veto_code == "VETO_3_CNH_RENACH_INVALID"

        v_unready = await orch.evaluate_kyc_dossier(
            user_id=user_id,
            typed_cpf=VALID_CPF_A,
            typed_full_name="Wagner Oliveira Claudiano",
            canonical_selfie_bytes=selfie,
            liveness_score=0.96,
            local_face_match_score=0.94,
            anti_swap_result=valid_as,
            argon_artifacts=_make_clean_argon_artifacts(ready_override=False),
            vio_result=vio_wagner_ok,
            serpro_result=None,
        )
        assert v_unready.status == "REJECTED"
        assert v_unready.hard_veto_code == "VETO_3_TIER1_DOSSIER_NOT_READY"

        # 5. Hard Veto 4: VIO QR Signed Civil Name Anti-Cloning
        #    Attacker forges front OCR + typed_full_name to "MARCOS ANTONIO SOUZA" while keeping
        #    the victim's CPF + authentic VIO QR signed for "WAGNER OLIVEIRA CLAUDIANO".
        v_name_clone = await orch.evaluate_kyc_dossier(
            user_id=user_id,
            typed_cpf=VALID_CPF_A,
            typed_full_name="Marcos Antonio Souza",
            canonical_selfie_bytes=selfie,
            liveness_score=0.96,
            local_face_match_score=0.94,
            anti_swap_result=valid_as,
            argon_artifacts=_make_clean_argon_artifacts(
                cpf=VALID_CPF_A,
                full_name="MARCOS ANTONIO SOUZA",
                typed_name_score=1.0,
            ),
            vio_result=vio_wagner_ok,
            serpro_result=serpro_ok,
        )
        assert v_name_clone.status == "REJECTED"
        assert v_name_clone.hard_veto_code == "VETO_4_VIO_CPF_CLONING_DETECTED"

        assert llm_calls["count"] == 0

    asyncio.run(_run_checks())

    # 6. End-to-End HTTP NaN/Infinity form submission: must reject cleanly & emit valid RFC 8259 JSON webhook
    captured_wh: list[bytes] = []
    serpro_http_calls = {"count": 0}

    async def _cap_wh(_url: str, raw: bytes, _headers: dict) -> int:
        captured_wh.append(raw)
        return 200

    async def _track_serpro(request: httpx.Request) -> httpx.Response:
        serpro_http_calls["count"] += 1
        return httpx.Response(500)

    tracked_serpro = SerproDatavalidMtlsClient(
        cfg, transport=httpx.MockTransport(_track_serpro)
    )
    app = create_kyc_app(
        settings=cfg,
        security_engine=sec,
        crypto_validator=crypto_val,
        serpro_client=tracked_serpro,
        fraud_orchestrator=orch,
        webhook_dispatcher=_cap_wh,
    )
    with TestClient(app) as client:
        ch_http = client.post(
            "/v1/kyc/session/init", json={"user_id": user_id, "now_ts": t0}
        ).json()
        rh_http = sec.compute_anti_swap_request_hash(
            user_id, ch_http["session_nonce"], sh, sh, sh
        )
        nan_resp = client.post(
            "/v1/kyc/verify-full",
            data={
                "user_id": user_id,
                "typed_cpf": VALID_CPF_A,
                "typed_full_name": "Wagner Oliveira Claudiano",
                "session_nonce": ch_http["session_nonce"],
                "session_issued_at": str(ch_http["issued_at"]),
                "session_signature": ch_http["session_signature"],
                "liveness_timestamp": str(t0 + 5),
                "doc_capture_timestamp": str(t0 + 15),
                "request_hash": rh_http,
                "liveness_score": "NaN",
                "local_face_match_score": "Infinity",
                "now_ts_override": str(t0 + 20),
            },
            files={
                "selfie_liveness": ("selfie.jpg", selfie, "image/jpeg"),
                "doc_front": ("front.jpg", selfie, "image/jpeg"),
                "doc_back": ("back.jpg", selfie, "image/jpeg"),
            },
        )
        assert nan_resp.status_code == 200
        assert nan_resp.json()["verdict"]["status"] == "REJECTED"
        assert (
            nan_resp.json()["verdict"]["hard_veto_code"]
            == "VETO_2_LIVENESS_BELOW_THRESHOLD"
        )
        assert serpro_http_calls["count"] == 0
        assert len(captured_wh) == 1
        parsed_wh = json.loads(captured_wh[0].decode("utf-8"))
        assert parsed_wh["liveness_score"] == 0.0
        assert parsed_wh["local_face_match_score"] == 0.0


def test_rfc5280_x509_key_usage_and_path_length_constraints() -> None:
    now = datetime.now(timezone.utc)
    payload = json.dumps(
        {"cpf": VALID_CPF_A, "name": "WAGNER OLIVEIRA CLAUDIANO"}
    ).encode("utf-8")

    def _make_three_tier_pki(
        *,
        root_path_len: int | None = 1,
        root_key_cert_sign: bool = True,
        inter_is_ca: bool = True,
        inter_path_len: int | None = 0,
        inter_key_cert_sign: bool = True,
        leaf_digital_sig: bool = True,
        leaf_content_commitment: bool = False,
    ) -> tuple[x509.Certificate, x509.Certificate, ec.EllipticCurvePrivateKey, x509.Certificate]:
        root_key = ec.generate_private_key(ec.SECP256R1())
        root_name = x509.Name(
            [
                x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
                x509.NameAttribute(NameOID.COMMON_NAME, "ICP-Brasil Root RFC5280 Test"),
            ]
        )
        root_cert = (
            x509.CertificateBuilder()
            .subject_name(root_name)
            .issuer_name(root_name)
            .public_key(root_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(days=365))
            .not_valid_after(now + timedelta(days=3650))
            .add_extension(
                x509.BasicConstraints(ca=True, path_length=root_path_len), critical=True
            )
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    content_commitment=False,
                    key_encipherment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    key_cert_sign=root_key_cert_sign,
                    crl_sign=True,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(root_key, hashes.SHA256())
        )

        inter_key = ec.generate_private_key(ec.SECP256R1())
        inter_name = x509.Name(
            [
                x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
                x509.NameAttribute(
                    NameOID.COMMON_NAME, "AC Intermediaria SENATRAN Test"
                ),
            ]
        )
        inter_cert = (
            x509.CertificateBuilder()
            .subject_name(inter_name)
            .issuer_name(root_name)
            .public_key(inter_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(days=180))
            .not_valid_after(now + timedelta(days=1800))
            .add_extension(
                x509.BasicConstraints(
                    ca=inter_is_ca,
                    path_length=inter_path_len if inter_is_ca else None,
                ),
                critical=True,
            )
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    content_commitment=False,
                    key_encipherment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    key_cert_sign=inter_key_cert_sign,
                    crl_sign=True,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(root_key, hashes.SHA256())
        )

        leaf_key = ec.generate_private_key(ec.SECP256R1())
        leaf_name = x509.Name(
            [
                x509.NameAttribute(NameOID.COUNTRY_NAME, "BR"),
                x509.NameAttribute(NameOID.COMMON_NAME, "Emissor Final VIO Test"),
            ]
        )
        leaf_cert = (
            x509.CertificateBuilder()
            .subject_name(leaf_name)
            .issuer_name(inter_name)
            .public_key(leaf_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(days=30))
            .not_valid_after(now + timedelta(days=365))
            .add_extension(
                x509.BasicConstraints(ca=False, path_length=None), critical=True
            )
            .add_extension(
                x509.KeyUsage(
                    digital_signature=leaf_digital_sig,
                    content_commitment=leaf_content_commitment,
                    key_encipherment=not (leaf_digital_sig or leaf_content_commitment),
                    data_encipherment=False,
                    key_agreement=False,
                    key_cert_sign=False,
                    crl_sign=False,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(inter_key, hashes.SHA256())
        )
        return root_cert, inter_cert, leaf_key, leaf_cert

    # 1. Valid 3-tier chain (Root path_length=1 -> Intermediate path_length=0 -> Leaf digital_signature=True)
    r_ok, i_ok, lk_ok, lc_ok = _make_three_tier_pki(root_path_len=1, inter_path_len=0)
    cms_ok = _build_cms_signed_data_der(
        payload_bytes=payload,
        signer_key=lk_ok,
        signer_cert=lc_ok,
        extra_certs=(i_ok,),
    )
    res_ok = GovCryptographicDocumentValidator(
        trusted_roots=[r_ok]
    ).validate_vio_payload_bytes(
        cms_ok, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A, now_utc=now
    )
    assert res_ok.valid is True and res_ok.cert_chain_valid is True

    # 2. Violated BasicConstraints.path_length (Root path_length=0 cannot authorize an Intermediate CA)
    r_pl, i_pl, lk_pl, lc_pl = _make_three_tier_pki(root_path_len=0, inter_path_len=0)
    cms_pl = _build_cms_signed_data_der(
        payload_bytes=payload,
        signer_key=lk_pl,
        signer_cert=lc_pl,
        extra_certs=(i_pl,),
    )
    res_pl = GovCryptographicDocumentValidator(
        trusted_roots=[r_pl]
    ).validate_vio_payload_bytes(
        cms_pl, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A, now_utc=now
    )
    assert res_pl.valid is False
    assert res_pl.cert_chain_valid is False
    assert res_pl.reason_code == "X509_TRUST_CHAIN_INVALID"

    # 3. Violated Intermediate CA KeyUsage (key_cert_sign=False)
    r_ku, i_ku, lk_ku, lc_ku = _make_three_tier_pki(inter_key_cert_sign=False)
    cms_ku = _build_cms_signed_data_der(
        payload_bytes=payload,
        signer_key=lk_ku,
        signer_cert=lc_ku,
        extra_certs=(i_ku,),
    )
    res_ku = GovCryptographicDocumentValidator(
        trusted_roots=[r_ku]
    ).validate_vio_payload_bytes(
        cms_ku, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A, now_utc=now
    )
    assert res_ku.valid is False
    assert res_ku.cert_chain_valid is False
    assert res_ku.reason_code == "X509_TRUST_CHAIN_INVALID"

    # 4. Violated Non-CA Intermediate (ca=False attempting to sign leaf certificate)
    r_nca, i_nca, lk_nca, lc_nca = _make_three_tier_pki(inter_is_ca=False)
    cms_nca = _build_cms_signed_data_der(
        payload_bytes=payload,
        signer_key=lk_nca,
        signer_cert=lc_nca,
        extra_certs=(i_nca,),
    )
    res_nca = GovCryptographicDocumentValidator(
        trusted_roots=[r_nca]
    ).validate_vio_payload_bytes(
        cms_nca, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A, now_utc=now
    )
    assert res_nca.valid is False
    assert res_nca.cert_chain_valid is False
    assert res_nca.reason_code == "X509_TRUST_CHAIN_INVALID"

    # 5. Violated Leaf KeyUsage (neither digital_signature nor content_commitment enabled)
    r_lf, i_lf, lk_lf, lc_lf = _make_three_tier_pki(
        leaf_digital_sig=False, leaf_content_commitment=False
    )
    cms_lf = _build_cms_signed_data_der(
        payload_bytes=payload,
        signer_key=lk_lf,
        signer_cert=lc_lf,
        extra_certs=(i_lf,),
    )
    res_lf = GovCryptographicDocumentValidator(
        trusted_roots=[r_lf]
    ).validate_vio_payload_bytes(
        cms_lf, ocr_cpf=VALID_CPF_A, typed_cpf=VALID_CPF_A, now_utc=now
    )
    assert res_lf.valid is False
    assert res_lf.cert_chain_valid is False
    assert res_lf.reason_code == "X509_TRUST_CHAIN_INVALID"

