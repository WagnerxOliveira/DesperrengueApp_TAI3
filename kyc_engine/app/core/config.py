"""Zero-Trust Configuration & Cryptographic Invariants for Desperrengue KYC Engine."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Literal, Optional, Tuple

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_HOMOLOGATION_MASTER_KEK_HEX = (
    "4b59435f484f4d4f4c4f474154494f4e5f4d41535445525f4b454b5f32353621"
)
_HOMOLOGATION_CPF_PEPPER = "DSP-HOMOLOG-CPF-PEPPER-2026-SECRET"
_HOMOLOGATION_SESSION_SECRET = "DSP-HOMOLOG-SESSION-HMAC-2026-SECRET"
_HOMOLOGATION_WEBHOOK_SECRET = "DSP-HOMOLOG-SUPABASE-WEBHOOK-2026-SECRET"


class KYCZeroTrustSettings(BaseSettings):
    """Centralized Zero-Trust configuration with strict production enforcement and homologation fallback."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    environment: Literal["production", "homologation", "development", "test"] = Field(
        default="homologation",
        validation_alias=AliasChoices("KYC_ENV", "ENVIRONMENT", "environment", "env"),
    )
    gemini_api_key: str = Field(
        default="",
        validation_alias=AliasChoices("GEMINI_API_KEY", "gemini_api_key"),
    )
    argon_model_id: str = Field(
        default="gemini-4-argon-high",
        validation_alias=AliasChoices("GEMINI_ARGON_MODEL", "argon_model_id"),
    )
    carbon_model_id: str = Field(
        default="gemini-4-carbon-high",
        validation_alias=AliasChoices("GEMINI_CARBON_MODEL", "carbon_model_id"),
    )

    # Cryptographic KMS / Vault secrets
    master_kek_hex: str = Field(
        default="",
        validation_alias=AliasChoices("KYC_MASTER_KEK_HEX", "master_kek_hex"),
    )
    cpf_pepper_secret: str = Field(
        default="",
        validation_alias=AliasChoices("KYC_CPF_PEPPER_SECRET", "cpf_pepper_secret"),
    )
    session_hmac_secret: str = Field(
        default="",
        validation_alias=AliasChoices("KYC_SESSION_HMAC_SECRET", "session_hmac_secret"),
    )
    supabase_webhook_secret: str = Field(
        default="",
        validation_alias=AliasChoices(
            "SUPABASE_KYC_WEBHOOK_SECRET", "supabase_webhook_secret"
        ),
    )
    supabase_webhook_url: str = Field(
        default="",
        validation_alias=AliasChoices("SUPABASE_KYC_WEBHOOK_URL", "supabase_webhook_url"),
    )

    # SERPRO Datavalid v4/v5 mTLS ICP-Brasil A1
    serpro_base_url: str = Field(
        default="https://gateway.apiserpro.serpro.gov.br/datavalid/v4",
        validation_alias=AliasChoices("SERPRO_BASE_URL", "serpro_base_url"),
    )
    serpro_consumer_key: str = Field(
        default="",
        validation_alias=AliasChoices("SERPRO_CONSUMER_KEY", "serpro_consumer_key"),
    )
    serpro_consumer_secret: str = Field(
        default="",
        validation_alias=AliasChoices("SERPRO_CONSUMER_SECRET", "serpro_consumer_secret"),
    )
    serpro_mtls_cert_pem_path: str = Field(
        default="",
        validation_alias=AliasChoices(
            "SERPRO_MTLS_CERT_PATH", "serpro_mtls_cert_pem_path"
        ),
    )
    serpro_mtls_key_pem_path: str = Field(
        default="",
        validation_alias=AliasChoices(
            "SERPRO_MTLS_KEY_PATH", "serpro_mtls_key_pem_path"
        ),
    )
    serpro_ca_bundle_pem_path: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SERPRO_CA_BUNDLE_PATH", "serpro_ca_bundle_pem_path"),
    )
    icp_brasil_trust_store_dir: str = Field(
        default="./certs/icp_brasil",
        validation_alias=AliasChoices(
            "ICP_BRASIL_CERTS_DIR", "icp_brasil_trust_store_dir"
        ),
    )

    # Deterministic Zero-Trust Security Thresholds (Invariants)
    max_session_ttl_seconds: int = Field(default=180, ge=30, le=600)
    max_liveness_window_seconds: int = Field(default=90, ge=15, le=300)
    min_liveness_score: float = Field(default=0.92, ge=0.50, le=1.0)
    min_local_face_match: float = Field(default=0.88, ge=0.50, le=1.0)
    min_serpro_face_similarity: float = Field(default=0.90, ge=0.50, le=1.0)
    min_name_compatibility_score: float = Field(default=0.80, ge=0.50, le=1.0)
    max_qr_decompressed_bytes: int = Field(default=65536, ge=1024, le=524288)
    webhook_max_skew_seconds: int = Field(default=300, ge=30, le=900)

    # Circuit Breaker tuning for SERPRO Datavalid
    serpro_cb_failure_threshold: int = Field(default=3, ge=1, le=20)
    serpro_cb_recovery_timeout_seconds: float = Field(default=30.0, ge=1.0, le=600.0)

    @model_validator(mode="after")
    def _enforce_zero_trust_secrets(self) -> "KYCZeroTrustSettings":
        if self.environment == "production":
            missing = []
            if not self.master_kek_hex:
                missing.append("KYC_MASTER_KEK_HEX")
            if not self.cpf_pepper_secret:
                missing.append("KYC_CPF_PEPPER_SECRET")
            if not self.session_hmac_secret:
                missing.append("KYC_SESSION_HMAC_SECRET")
            if not self.supabase_webhook_secret:
                missing.append("SUPABASE_KYC_WEBHOOK_SECRET")
            if not self.supabase_webhook_url:
                missing.append("SUPABASE_KYC_WEBHOOK_URL")
            if not self.gemini_api_key:
                missing.append("GEMINI_API_KEY")
            if missing:
                raise ValueError(
                    f"Segredos obrigatórios ausentes em ambiente de produção: {', '.join(missing)}"
                )
            if self.master_kek_hex == _HOMOLOGATION_MASTER_KEK_HEX:
                raise ValueError(
                    "Chave de homologação não é permitida quando environment='production'."
                )
        else:
            if not self.master_kek_hex:
                self.master_kek_hex = _HOMOLOGATION_MASTER_KEK_HEX
            if not self.cpf_pepper_secret:
                self.cpf_pepper_secret = _HOMOLOGATION_CPF_PEPPER
            if not self.session_hmac_secret:
                self.session_hmac_secret = _HOMOLOGATION_SESSION_SECRET
            if not self.supabase_webhook_secret:
                self.supabase_webhook_secret = _HOMOLOGATION_WEBHOOK_SECRET

        try:
            kek_bytes = bytes.fromhex(self.master_kek_hex)
        except ValueError as exc:
            raise ValueError(
                "KYC_MASTER_KEK_HEX deve conter caracteres hexadecimais válidos."
            ) from exc
        if len(kek_bytes) != 32:
            raise ValueError(
                "KYC_MASTER_KEK_HEX deve conter exatos 32 bytes (64 caracteres hex)."
            )
        return self

    @property
    def env(self) -> str:
        return self.environment

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def serpro_cert_tuple(self) -> Tuple[str, str]:
        return (self.serpro_mtls_cert_pem_path, self.serpro_mtls_key_pem_path)

    @property
    def has_serpro_mtls_credentials(self) -> bool:
        if not (
            self.serpro_consumer_key
            and self.serpro_consumer_secret
            and self.serpro_mtls_cert_pem_path
            and self.serpro_mtls_key_pem_path
        ):
            return False
        return (
            Path(self.serpro_mtls_cert_pem_path).is_file()
            and Path(self.serpro_mtls_key_pem_path).is_file()
        )


def load_settings() -> KYCZeroTrustSettings:
    """Loads settings cleanly from current process environment."""
    env_override = os.getenv("KYC_ENV") or os.getenv("ENVIRONMENT")
    if env_override:
        return KYCZeroTrustSettings(environment=env_override)  # type: ignore[arg-type]
    return KYCZeroTrustSettings()
