"""Zero-Trust Cryptographic Core: WORM AES-256-GCM, Anti-Sybil HMAC, Anti-Swap 180s & LGPD Filter."""

from __future__ import annotations

from enum import Enum
import hashlib
import hmac
import logging
import os
import re
import secrets
import time
from typing import Dict, Optional, Union

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from pydantic import BaseModel, Field

from app.core.config import KYCZeroTrustSettings, _HOMOLOGATION_WEBHOOK_SECRET

_WORM_ENVELOPE_MAGIC = b"KWV2"
_WORM_HKDF_INFO = b"desperrengue-kyc-worm-v2"
_WORM_SALT_LEN = 16
_WORM_NONCE_LEN = 12
_WORM_MIN_TAG_LEN = 16

_VIRTUAL_CAMERA_REGEX = re.compile(
    r"(?i)\b(obs|vcam|virtual[\s_-]*cam|manycam|droidcam|xsplit|snap[\s_-]*camera|fakecam|magisk|epoccam|iriun)\b"
)
_FORMATTED_CPF_REGEX = re.compile(r"(?<!\d)(\d{3})\.(\d{3})\.(\d{3})-(\d{2})(?!\d)")
_RAW_11_DIGIT_CPF_REGEX = re.compile(r"(?<!\d)(\d{3})(\d{3})(\d{3})(\d{2})(?!\d)")
_SECRET_TOKEN_LOG_REGEX = re.compile(
    r"(?i)(bearer\s+|api[_-]?key\s*[=:]\s*|x-kyc-signature\s*[=:]\s*|session[_-]?signature\s*[=:]\s*|webhook[_-]?secret\s*[=:]\s*)([A-Za-z0-9._\-+/=]{8,})"
)


class HardwareAttestationVerdict(str, Enum):
    """Supported hardware-backed device attestation verdicts."""

    MEETS_STRONG_INTEGRITY = "MEETS_STRONG_INTEGRITY"
    DC_APP_ATTEST_VERIFIED = "DC_APP_ATTEST_VERIFIED"
    APP_ATTEST_HARDWARE = "APP_ATTEST_HARDWARE"
    WEB_LIMITED_ALCADA = "WEB_LIMITED_ALCADA"
    WEB_STEP_UP_CONTAINED = "WEB_STEP_UP_CONTAINED"
    HOMOLOGATION_LIMITED = "HOMOLOGATION_LIMITED"
    FAILED = "FAILED"
    ROOTED_OR_HOOKED = "ROOTED_OR_HOOKED"
    UNTRUSTED = "UNTRUSTED"


class AntiSwapSessionChallenge(BaseModel):
    """Server-issued HMAC-signed challenge binding user_id, CSPRNG nonce, and t0."""

    user_id: str
    session_nonce: str
    issued_at: int
    expires_at: int
    ttl_seconds: int = Field(default=180)
    max_liveness_window_seconds: int = Field(default=90)
    session_signature: str


class AntiSwapVerificationResult(BaseModel):
    """Outcome of the Zero-Trust Anti-Swap (<=180s), Live Camera, and Hardware Attestation gate."""

    valid: bool
    reason_code: str
    alcada_restriction: Optional[str] = None
    computed_request_hash: str
    device_integrity_verdict: str


def redact_pii_text(text: str) -> str:
    """Masks any formatted/raw 11-digit CPF and sensitive bearer/signature tokens for LGPD compliance."""
    if not text:
        return text
    redacted = _FORMATTED_CPF_REGEX.sub(r"***. \2.\3-**".replace(" ", ""), text)
    redacted = _RAW_11_DIGIT_CPF_REGEX.sub(r"***. \2.\3-**".replace(" ", ""), redacted)
    redacted = _SECRET_TOKEN_LOG_REGEX.sub(r"\1[REDACTED_SECRET]", redacted)
    return redacted


class PiiRedactingLogFilter(logging.Filter):
    """Logging filter that strips raw CPFs and cryptographic tokens before records leave memory."""

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            rendered = record.getMessage()
            sanitized = redact_pii_text(rendered)
            record.msg = sanitized
            record.args = ()
        except Exception:
            if isinstance(record.msg, str):
                record.msg = redact_pii_text(record.msg)
        return True


class ZeroTrustSecurityEngine:
    """Implements WORM AES-256-GCM envelope encryption, Anti-Sybil HMAC, Anti-Swap 180s & Webhook MAC."""

    def __init__(
        self,
        settings_or_kek_hex: Union[KYCZeroTrustSettings, str, None] = None,
        cpf_pepper: Optional[str] = None,
        session_secret: Optional[str] = None,
        *,
        supabase_webhook_secret: Optional[str] = None,
        environment: Optional[str] = None,
        max_session_ttl_seconds: Optional[int] = None,
        max_liveness_window_seconds: Optional[int] = None,
    ) -> None:
        if isinstance(settings_or_kek_hex, KYCZeroTrustSettings):
            cfg = settings_or_kek_hex
            kek_hex = cfg.master_kek_hex
            pepper = cpf_pepper if cpf_pepper is not None else cfg.cpf_pepper_secret
            sess_sec = (
                session_secret if session_secret is not None else cfg.session_hmac_secret
            )
            wh_sec = (
                supabase_webhook_secret
                if supabase_webhook_secret is not None
                else cfg.supabase_webhook_secret
            )
            env_mode = environment if environment is not None else cfg.environment
            ttl_sec = (
                max_session_ttl_seconds
                if max_session_ttl_seconds is not None
                else cfg.max_session_ttl_seconds
            )
            live_win_sec = (
                max_liveness_window_seconds
                if max_liveness_window_seconds is not None
                else cfg.max_liveness_window_seconds
            )
        elif isinstance(settings_or_kek_hex, str):
            kek_hex = settings_or_kek_hex
            if not cpf_pepper or not session_secret:
                raise ValueError(
                    "cpf_pepper e session_secret são obrigatórios ao inicializar por string."
                )
            pepper = cpf_pepper
            sess_sec = session_secret
            wh_sec = supabase_webhook_secret or _HOMOLOGATION_WEBHOOK_SECRET
            env_mode = environment or "homologation"
            ttl_sec = max_session_ttl_seconds or 180
            live_win_sec = max_liveness_window_seconds or 90
        else:
            cfg = KYCZeroTrustSettings()
            kek_hex = cfg.master_kek_hex
            pepper = cpf_pepper or cfg.cpf_pepper_secret
            sess_sec = session_secret or cfg.session_hmac_secret
            wh_sec = supabase_webhook_secret or cfg.supabase_webhook_secret
            env_mode = environment or cfg.environment
            ttl_sec = max_session_ttl_seconds or cfg.max_session_ttl_seconds
            live_win_sec = (
                max_liveness_window_seconds or cfg.max_liveness_window_seconds
            )

        try:
            self._master_kek = bytes.fromhex(kek_hex)
        except ValueError as exc:
            raise ValueError(
                "KYC_MASTER_KEK_HEX deve conter exatamente 64 caracteres hexadecimais."
            ) from exc
        if len(self._master_kek) != 32:
            raise ValueError(
                "KYC_MASTER_KEK_HEX deve conter exatos 32 bytes (64 caracteres hex)."
            )

        self._cpf_pepper = pepper.encode("utf-8")
        self._session_secret = sess_sec.encode("utf-8")
        self._webhook_secret = wh_sec.encode("utf-8")
        self._environment = env_mode
        self._max_session_ttl_seconds = int(ttl_sec)
        self._max_liveness_window_seconds = int(live_win_sec)
        self._consumed_nonces: Dict[str, int] = {}

    @staticmethod
    def sha256_hex(payload: bytes) -> str:
        return hashlib.sha256(payload).hexdigest()

    @staticmethod
    def _to_bytes(value: Union[bytes, str]) -> bytes:
        if isinstance(value, bytes):
            return value
        if isinstance(value, str):
            return value.encode("utf-8")
        raise TypeError("Esperado bytes ou str.")

    def _derive_worm_key(self, salt: bytes) -> bytes:
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            info=_WORM_HKDF_INFO,
        )
        return hkdf.derive(self._master_kek)

    def encrypt_evidence_worm(
        self, plaintext: bytes, context_aad: Union[bytes, str]
    ) -> bytes:
        """Encrypts forensic evidence into an authenticated WORM blob (HKDF-SHA256 + AES-256-GCM)."""
        if not isinstance(plaintext, (bytes, bytearray)):
            raise TypeError("plaintext deve ser bytes.")
        aad_bytes = self._to_bytes(context_aad)
        salt = os.urandom(_WORM_SALT_LEN)
        nonce = os.urandom(_WORM_NONCE_LEN)
        derived_key = self._derive_worm_key(salt)
        ciphertext_with_tag = AESGCM(derived_key).encrypt(
            nonce, bytes(plaintext), aad_bytes
        )
        return _WORM_ENVELOPE_MAGIC + salt + nonce + ciphertext_with_tag

    def decrypt_evidence_worm(
        self, blob: bytes, context_aad: Union[bytes, str]
    ) -> bytes:
        """Verifies authentication tag + AAD and decrypts a WORM evidence blob."""
        if not isinstance(blob, (bytes, bytearray)):
            raise TypeError("blob deve ser bytes.")
        min_len = (
            len(_WORM_ENVELOPE_MAGIC)
            + _WORM_SALT_LEN
            + _WORM_NONCE_LEN
            + _WORM_MIN_TAG_LEN
        )
        if len(blob) < min_len or blob[:4] != _WORM_ENVELOPE_MAGIC:
            raise ValueError("Envelope WORM inválido ou corrompido.")
        aad_bytes = self._to_bytes(context_aad)
        salt = bytes(blob[4 : 4 + _WORM_SALT_LEN])
        nonce = bytes(
            blob[4 + _WORM_SALT_LEN : 4 + _WORM_SALT_LEN + _WORM_NONCE_LEN]
        )
        ciphertext_with_tag = bytes(
            blob[4 + _WORM_SALT_LEN + _WORM_NONCE_LEN :]
        )
        derived_key = self._derive_worm_key(salt)
        try:
            return AESGCM(derived_key).decrypt(nonce, ciphertext_with_tag, aad_bytes)
        except InvalidTag as exc:
            raise InvalidTag(
                "Falha de autenticação AES-256-GCM: evidência ou AAD adulterado."
            ) from exc

    def hash_cpf_anti_sybil(self, cpf_digits: str) -> str:
        """Pseudonymizes CPF via HMAC-SHA256 with secret pepper for Anti-Sybil uniqueness."""
        clean = "".join(ch for ch in (cpf_digits or "") if ch.isdigit())
        if len(clean) != 11:
            raise ValueError("CPF inválido para derivação criptográfica Anti-Sybil.")
        return hmac.new(
            self._cpf_pepper, clean.encode("utf-8"), hashlib.sha256
        ).hexdigest()

    def hash_biometric_liveness(self, canonical_selfie_bytes: bytes) -> str:
        """Computes irreversible HMAC-SHA256 pseudonym over canonical liveness selfie bytes."""
        if not canonical_selfie_bytes:
            raise ValueError("Bytes da selfie canônica não podem ser vazios.")
        msg = b"DSP-CARBON-BIOMETRIC-V2:" + bytes(canonical_selfie_bytes)
        return hmac.new(self._cpf_pepper, msg, hashlib.sha256).hexdigest()

    @staticmethod
    def mask_cpf_lgpd(cpf_digits: str) -> str:
        """Formats CPF according to LGPD data minimization (`***.456.789-**`)."""
        clean = "".join(ch for ch in (cpf_digits or "") if ch.isdigit())
        if len(clean) != 11:
            return "***.***.***-**"
        return f"***.{clean[3:6]}.{clean[6:9]}-**"

    def _compute_session_hmac(
        self, user_id: str, session_nonce: str, issued_at: int
    ) -> str:
        canonical = f"{user_id}|{session_nonce}|{issued_at}".encode("utf-8")
        return hmac.new(self._session_secret, canonical, hashlib.sha256).hexdigest()

    def issue_anti_swap_session_token(
        self, user_id: str, now_ts: Optional[int] = None
    ) -> AntiSwapSessionChallenge:
        """Issues an HMAC-SHA256 bound session challenge with strict 180s TTL."""
        clean_uid = (user_id or "").strip()
        if not clean_uid:
            raise ValueError("user_id é obrigatório para emissão de sessão KYC.")
        t0 = int(now_ts if now_ts is not None else time.time())
        nonce = secrets.token_hex(16)
        sig = self._compute_session_hmac(clean_uid, nonce, t0)
        return AntiSwapSessionChallenge(
            user_id=clean_uid,
            session_nonce=nonce,
            issued_at=t0,
            expires_at=t0 + self._max_session_ttl_seconds,
            ttl_seconds=self._max_session_ttl_seconds,
            max_liveness_window_seconds=self._max_liveness_window_seconds,
            session_signature=sig,
        )

    @staticmethod
    def compute_anti_swap_request_hash(
        user_id: str,
        session_nonce: str,
        selfie_hash: str,
        doc_front_hash: str,
        doc_back_hash: str,
    ) -> str:
        """Computes canonical SHA-256 request commitment binding identity, nonce, selfie and document sides."""
        payload = (
            f"{user_id}|{session_nonce}|{selfie_hash.lower()}|"
            f"{doc_front_hash.lower()}|{doc_back_hash.lower()}"
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    def _prune_expired_nonces(self, now_sec: int) -> None:
        cutoff = now_sec - (self._max_session_ttl_seconds * 4)
        expired = [n for n, ts in self._consumed_nonces.items() if ts < cutoff]
        for n in expired:
            self._consumed_nonces.pop(n, None)

    def verify_anti_swap_and_device_integrity(
        self,
        *,
        user_id: str,
        session_nonce: str,
        session_issued_at: int,
        session_signature: str,
        liveness_timestamp: int,
        doc_capture_timestamp: int,
        selfie_hash: str,
        doc_front_hash: str,
        doc_back_hash: str,
        request_hash: str,
        capture_source: str = "LIVE_CAMERA",
        platform: str = "ANDROID",
        attestation_verdict: Union[HardwareAttestationVerdict, str] = (
            HardwareAttestationVerdict.MEETS_STRONG_INTEGRITY
        ),
        camera_device_label: str = "",
        virtual_camera_suspected: bool = False,
        now_ts: Optional[int] = None,
    ) -> AntiSwapVerificationResult:
        """Validates HMAC session token, <=90s/<=180s temporal windows, request_hash, live camera & hardware TEE."""
        now = int(now_ts if now_ts is not None else time.time())
        self._prune_expired_nonces(now)

        verdict_str = (
            attestation_verdict.value
            if isinstance(attestation_verdict, HardwareAttestationVerdict)
            else str(attestation_verdict or "").strip().upper()
        )
        canonical_req_hash = self.compute_anti_swap_request_hash(
            user_id=user_id,
            session_nonce=session_nonce,
            selfie_hash=selfie_hash,
            doc_front_hash=doc_front_hash,
            doc_back_hash=doc_back_hash,
        )

        # 1. Constant-time Session HMAC check
        expected_sig = self._compute_session_hmac(
            user_id, session_nonce, int(session_issued_at)
        )
        provided_sig = (session_signature or "").strip().lower()
        if not provided_sig or not hmac.compare_digest(expected_sig, provided_sig):
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="INVALID_SESSION_HMAC",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 2. Anti-Replay single-use nonce check
        if session_nonce in self._consumed_nonces:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="SESSION_REPLAY_DETECTED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 3. Live Camera Enforcement (Gallery / Static Injection Hard Reject)
        if (capture_source or "").strip().upper() != "LIVE_CAMERA":
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="GALLERY_UPLOAD_BLOCKED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 4. Virtual Camera Injection Detection (OBS / Magisk VCam / ManyCam / DroidCam)
        if virtual_camera_suspected or _VIRTUAL_CAMERA_REGEX.search(
            camera_device_label or ""
        ):
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="VIRTUAL_CAMERA_SUSPECTED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 5. Strict Temporal Windows:
        #    0 <= (t_liveness - t0) <= 90s
        #    0 <= (t_doc - t_liveness) <= 180s
        #    0 <= (now - t0) <= 180s
        delta_liveness = int(liveness_timestamp) - int(session_issued_at)
        if delta_liveness < 0 or delta_liveness > self._max_liveness_window_seconds:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="LIVENESS_WINDOW_EXCEEDED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        delta_doc = int(doc_capture_timestamp) - int(liveness_timestamp)
        if delta_doc < 0 or delta_doc > self._max_session_ttl_seconds:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="ANTI_SWAP_WINDOW_EXCEEDED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        total_elapsed = now - int(session_issued_at)
        if total_elapsed < 0 or total_elapsed > self._max_session_ttl_seconds:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="SESSION_TTL_EXPIRED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        if int(doc_capture_timestamp) > now + 5:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="FUTURE_CAPTURE_TIMESTAMP_INVALID",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 6. Cryptographic Request Hash Verification (constant-time compare_digest)
        provided_req_hash = (request_hash or "").strip().lower()
        concat_5_hash = hashlib.sha256(
            f"{user_id}{session_nonce}{selfie_hash.lower()}{doc_front_hash.lower()}{doc_back_hash.lower()}".encode(
                "utf-8"
            )
        ).hexdigest()
        pipe_6_hash = hashlib.sha256(
            f"{user_id}|{session_nonce}|{selfie_hash.lower()}|{doc_front_hash.lower()}|{doc_back_hash.lower()}|{int(doc_capture_timestamp)}".encode(
                "utf-8"
            )
        ).hexdigest()

        hash_ok = bool(provided_req_hash) and (
            hmac.compare_digest(canonical_req_hash, provided_req_hash)
            or hmac.compare_digest(concat_5_hash, provided_req_hash)
            or hmac.compare_digest(pipe_6_hash, provided_req_hash)
        )
        if not hash_ok:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="REQUEST_HASH_MISMATCH",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "UNKNOWN",
            )

        # 7. Hardware Attestation Policy (Play Integrity / DCAppAttestService / Controlled PWA Fallback)
        norm_platform = (platform or "ANDROID").strip().upper()
        alcada_restriction: Optional[str] = None

        if verdict_str in {
            HardwareAttestationVerdict.FAILED.value,
            HardwareAttestationVerdict.ROOTED_OR_HOOKED.value,
            HardwareAttestationVerdict.UNTRUSTED.value,
            "",
        }:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="DEVICE_ATTESTATION_FAILED",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str or "FAILED",
            )

        if norm_platform == "ANDROID":
            if verdict_str == HardwareAttestationVerdict.MEETS_STRONG_INTEGRITY.value:
                alcada_restriction = None
            elif self._environment != "production" and verdict_str in {
                HardwareAttestationVerdict.WEB_LIMITED_ALCADA.value,
                HardwareAttestationVerdict.HOMOLOGATION_LIMITED.value,
                HardwareAttestationVerdict.WEB_STEP_UP_CONTAINED.value,
            }:
                alcada_restriction = "WEB_LIMITED_ALCADA"
            else:
                return AntiSwapVerificationResult(
                    valid=False,
                    reason_code="ANDROID_PLAY_INTEGRITY_FAILED",
                    computed_request_hash=canonical_req_hash,
                    device_integrity_verdict=verdict_str,
                )
        elif norm_platform == "IOS":
            if verdict_str in {
                HardwareAttestationVerdict.DC_APP_ATTEST_VERIFIED.value,
                HardwareAttestationVerdict.APP_ATTEST_HARDWARE.value,
            }:
                alcada_restriction = None
            elif self._environment != "production" and verdict_str in {
                HardwareAttestationVerdict.WEB_LIMITED_ALCADA.value,
                HardwareAttestationVerdict.HOMOLOGATION_LIMITED.value,
                HardwareAttestationVerdict.WEB_STEP_UP_CONTAINED.value,
            }:
                alcada_restriction = "WEB_LIMITED_ALCADA"
            else:
                return AntiSwapVerificationResult(
                    valid=False,
                    reason_code="IOS_APP_ATTEST_FAILED",
                    computed_request_hash=canonical_req_hash,
                    device_integrity_verdict=verdict_str,
                )
        elif norm_platform in {"WEB", "PWA"}:
            if verdict_str in {
                HardwareAttestationVerdict.WEB_LIMITED_ALCADA.value,
                HardwareAttestationVerdict.WEB_STEP_UP_CONTAINED.value,
                HardwareAttestationVerdict.HOMOLOGATION_LIMITED.value,
            }:
                alcada_restriction = "WEB_LIMITED_ALCADA"
            else:
                return AntiSwapVerificationResult(
                    valid=False,
                    reason_code="WEB_ATTESTATION_VERDICT_INVALID",
                    computed_request_hash=canonical_req_hash,
                    device_integrity_verdict=verdict_str,
                )
        else:
            return AntiSwapVerificationResult(
                valid=False,
                reason_code="UNSUPPORTED_DEVICE_PLATFORM",
                computed_request_hash=canonical_req_hash,
                device_integrity_verdict=verdict_str,
            )

        self._consumed_nonces[session_nonce] = now
        return AntiSwapVerificationResult(
            valid=True,
            reason_code="OK",
            alcada_restriction=alcada_restriction,
            computed_request_hash=canonical_req_hash,
            device_integrity_verdict=verdict_str,
        )

    def sign_supabase_webhook(self, raw_body: bytes, timestamp_sec: int) -> str:
        """Signs `<timestamp_sec>.<raw_body>` with HMAC-SHA256 for the Supabase bridge."""
        if not isinstance(raw_body, (bytes, bytearray)):
            raise TypeError("raw_body deve ser bytes.")
        prefix = f"{int(timestamp_sec)}.".encode("ascii")
        return hmac.new(
            self._webhook_secret, prefix + bytes(raw_body), hashlib.sha256
        ).hexdigest()

    def verify_supabase_webhook(
        self,
        raw_body: bytes,
        timestamp_sec: int,
        signature_hex: str,
        max_skew_sec: int = 300,
        now_ts: Optional[int] = None,
    ) -> bool:
        """Verifies webhook anti-replay skew window and constant-time HMAC-SHA256 signature."""
        now = int(now_ts if now_ts is not None else time.time())
        if abs(now - int(timestamp_sec)) > int(max_skew_sec):
            return False
        expected = self.sign_supabase_webhook(raw_body, int(timestamp_sec))
        provided = (signature_hex or "").strip().lower()
        if len(provided) != len(expected):
            return False
        return hmac.compare_digest(
            expected.encode("ascii"), provided.encode("ascii")
        )
