"""Resilient SERPRO Datavalid v4/v5 Client: Strict TLS 1.3 mTLS Pool, OAuth2 Lock & Circuit Breaker."""

from __future__ import annotations

import asyncio
import base64
from enum import Enum
import logging
import math
import ssl
import time
from typing import Callable, Optional

import httpx
from pydantic import BaseModel, Field, field_validator

from app.core.config import KYCZeroTrustSettings
from app.core.security import PiiRedactingLogFilter, ZeroTrustSecurityEngine

logger = logging.getLogger("desperrengue.kyc.serpro")
logger.addFilter(PiiRedactingLogFilter())


class CircuitState(str, Enum):
    """States of the SERPRO Datavalid Circuit Breaker."""

    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"


class SerproCircuitOpenError(RuntimeError):
    """Raised when SERPRO Datavalid Circuit Breaker is OPEN to prevent cascading timeouts."""


class SerproBiometricResult(BaseModel):
    """Normalized 1:1 government biometric triangulation response."""

    passed: bool
    similarity: float = Field(ge=0.0, le=1.0)
    cpf_regular: bool
    active_external_mtls: bool
    mode: str
    circuit_state: CircuitState
    reason_code: str

    @field_validator("similarity")
    @classmethod
    def _ensure_finite_similarity(cls, value: float) -> float:
        if not math.isfinite(float(value)):
            raise ValueError("similarity deve ser um número real finito no intervalo [0.0, 1.0].")
        return float(value)


def create_tls13_mtls_ssl_context(
    *,
    cert_pem_path: Optional[str] = None,
    key_pem_path: Optional[str] = None,
    ca_bundle_pem_path: Optional[str] = None,
) -> ssl.SSLContext:
    """Creates a strict TLS 1.3 SSLContext configured for ICP-Brasil mTLS client authentication."""
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ssl_ctx.minimum_version = ssl.TLSVersion.TLSv1_3
    ssl_ctx.check_hostname = True
    ssl_ctx.verify_mode = ssl.CERT_REQUIRED

    if ca_bundle_pem_path:
        ssl_ctx.load_verify_locations(cafile=ca_bundle_pem_path)
    else:
        ssl_ctx.load_default_certs(purpose=ssl.Purpose.SERVER_AUTH)

    if cert_pem_path and key_pem_path:
        ssl_ctx.load_cert_chain(certfile=cert_pem_path, keyfile=key_pem_path)

    return ssl_ctx


class SerproDatavalidMtlsClient:
    """
    High-resilience asynchronous SERPRO Datavalid v4/v5 client:
    - Persistent httpx.AsyncClient connection pool over TLS 1.3 + ICP-Brasil mTLS;
    - Double-checked OAuth2 Bearer token cache guarded by asyncio.Lock();
    - Deterministic Circuit Breaker (CLOSED -> OPEN -> HALF_OPEN -> CLOSED);
    - Transparent homologation fallback when external mTLS certs are absent in dev/test.
    """

    def __init__(
        self,
        settings: KYCZeroTrustSettings,
        *,
        transport: Optional[httpx.AsyncBaseTransport] = None,
        clock_fn: Callable[[], float] = time.monotonic,
    ) -> None:
        self._settings = settings
        self._clock = clock_fn
        self._token_lock = asyncio.Lock()
        self._access_token: Optional[str] = None
        self._token_expires_at: float = 0.0

        self._consecutive_failures: int = 0
        self._circuit_state: CircuitState = CircuitState.CLOSED
        self._circuit_open_until: float = 0.0
        self._half_open_probe_in_flight: bool = False

        has_mtls = settings.has_serpro_mtls_credentials
        if settings.is_production and not has_mtls and transport is None:
            raise ValueError(
                "Certificados mTLS ICP-Brasil e credenciais SERPRO são obrigatórios em produção."
            )

        self._external_mode_enabled = bool(has_mtls or transport is not None)
        self.ssl_context: ssl.SSLContext = create_tls13_mtls_ssl_context(
            cert_pem_path=settings.serpro_mtls_cert_pem_path if has_mtls else None,
            key_pem_path=settings.serpro_mtls_key_pem_path if has_mtls else None,
            ca_bundle_pem_path=settings.serpro_ca_bundle_pem_path,
        )

        client_kwargs = {
            "base_url": settings.serpro_base_url.rstrip("/"),
            "timeout": httpx.Timeout(connect=5.0, read=12.0, write=5.0, pool=5.0),
            "limits": httpx.Limits(max_keepalive_connections=20, max_connections=50),
        }
        if transport is not None:
            client_kwargs["transport"] = transport
        else:
            client_kwargs["verify"] = self.ssl_context

        self._http = httpx.AsyncClient(**client_kwargs)

    @property
    def circuit_state(self) -> CircuitState:
        now = self._clock()
        if (
            self._circuit_state == CircuitState.OPEN
            and now >= self._circuit_open_until
        ):
            self._circuit_state = CircuitState.HALF_OPEN
        return self._circuit_state

    async def close(self) -> None:
        """Closes persistent mTLS socket pool cleanly during FastAPI lifespan shutdown."""
        await self._http.aclose()

    def _before_request_circuit_check(self) -> None:
        state = self.circuit_state
        if state == CircuitState.OPEN:
            raise SerproCircuitOpenError(
                "SERPRO_CIRCUIT_OPEN: Circuito temporariamente aberto para evitar cascata de timeouts."
            )
        if state == CircuitState.HALF_OPEN:
            if self._half_open_probe_in_flight:
                raise SerproCircuitOpenError(
                    "SERPRO_CIRCUIT_HALF_OPEN_BUSY: Sonda de recuperação já em andamento."
                )
            self._half_open_probe_in_flight = True

    def _record_success(self) -> None:
        self._consecutive_failures = 0
        self._circuit_state = CircuitState.CLOSED
        self._circuit_open_until = 0.0
        self._half_open_probe_in_flight = False

    def _record_failure(self) -> None:
        self._half_open_probe_in_flight = False
        self._consecutive_failures += 1
        if (
            self._circuit_state == CircuitState.HALF_OPEN
            or self._consecutive_failures >= self._settings.serpro_cb_failure_threshold
        ):
            self._circuit_state = CircuitState.OPEN
            self._circuit_open_until = (
                self._clock() + self._settings.serpro_cb_recovery_timeout_seconds
            )

    async def _get_valid_oauth_token(self) -> str:
        """Double-checked locking OAuth2 token acquisition with 30-second proactive renewal margin."""
        now = self._clock()
        if self._access_token and now < (self._token_expires_at - 30.0):
            return self._access_token

        async with self._token_lock:
            now = self._clock()
            if self._access_token and now < (self._token_expires_at - 30.0):
                return self._access_token

            raw_creds = (
                f"{self._settings.serpro_consumer_key}:"
                f"{self._settings.serpro_consumer_secret}"
            )
            basic_b64 = base64.b64encode(raw_creds.encode("utf-8")).decode("ascii")
            resp = await self._http.post(
                "/token",
                headers={
                    "Authorization": f"Basic {basic_b64}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                data={"grant_type": "client_credentials"},
            )
            resp.raise_for_status()
            payload = resp.json()
            token = str(payload.get("access_token") or "").strip()
            if not token:
                raise RuntimeError("Resposta OAuth2 do SERPRO sem access_token.")
            expires_in = float(payload.get("expires_in", 3600))
            self._access_token = token
            self._token_expires_at = self._clock() + max(60.0, expires_in)
            return token

    async def validate_pf_facial_biometrics(
        self,
        *,
        cpf_digits: str,
        canonical_selfie_bytes: bytes,
        full_name: Optional[str] = None,
    ) -> SerproBiometricResult:
        """Executes 1:1 facial biometric triangulation against SERPRO Datavalid (threshold >= 0.90)."""
        clean_cpf = "".join(ch for ch in (cpf_digits or "") if ch.isdigit())
        if len(clean_cpf) != 11:
            raise ValueError("CPF deve possuir 11 dígitos para consulta SERPRO.")
        if not canonical_selfie_bytes:
            raise ValueError("Selfie canônica obrigatória para triangulação SERPRO.")

        masked_cpf = ZeroTrustSecurityEngine.mask_cpf_lgpd(clean_cpf)

        # Transparent deterministic homologation mode when external mTLS is absent in dev/test
        if not self._external_mode_enabled:
            logger.info(
                "SERPRO Datavalid em modo homologação determinística para %s",
                masked_cpf,
            )
            return SerproBiometricResult(
                passed=True,
                similarity=0.95,
                cpf_regular=True,
                active_external_mtls=False,
                mode="HOMOLOGATION_LOCAL",
                circuit_state=self.circuit_state,
                reason_code="HOMOLOGATION_DETERMINISTIC_OK",
            )

        self._before_request_circuit_check()

        try:
            bearer_token = await self._get_valid_oauth_token()
            selfie_b64 = base64.b64encode(canonical_selfie_bytes).decode("ascii")
            req_body = {
                "key": {"pk": clean_cpf},
                "answer": {
                    "biometria_face": selfie_b64,
                    **({"nome": full_name} if full_name else {}),
                },
            }
            resp = await self._http.post(
                "/pf-face",
                headers={
                    "Authorization": f"Bearer {bearer_token}",
                    "Content-Type": "application/json",
                },
                json=req_body,
            )
            if resp.status_code >= 500 or resp.status_code == 429:
                resp.raise_for_status()
            resp.raise_for_status()
            data = resp.json()
            self._record_success()
        except SerproCircuitOpenError:
            raise
        except Exception as exc:
            self._record_failure()
            logger.warning(
                "Falha na comunicação mTLS com SERPRO Datavalid para %s (estado=%s): %s",
                masked_cpf,
                self.circuit_state.value,
                type(exc).__name__,
            )
            raise

        bio_obj = data.get("biometria_face")
        try:
            if isinstance(bio_obj, dict):
                raw_sim = float(bio_obj.get("similaridade", 0.0))
            else:
                raw_sim = float(data.get("similaridade", 0.0))
        except (TypeError, ValueError):
            raw_sim = float("nan")

        if not math.isfinite(raw_sim) or raw_sim < 0.0 or raw_sim > 100.0:
            similarity = 0.0
            sim_valid = False
        else:
            similarity = (raw_sim / 100.0) if raw_sim > 1.0 else raw_sim
            similarity = max(0.0, min(1.0, similarity))
            sim_valid = True

        cpf_situacao = data.get("situacao_cpf", data.get("cpf_disponivel", True))
        if isinstance(cpf_situacao, str):
            cpf_regular = cpf_situacao.strip().lower() in {"regular", "ativa", "true"}
        else:
            cpf_regular = bool(cpf_situacao)

        passed = (
            sim_valid
            and cpf_regular
            and similarity >= self._settings.min_serpro_face_similarity
        )
        reason = (
            "OK"
            if passed
            else (
                "SERPRO_INVALID_SIMILARITY_VALUE"
                if not sim_valid
                else (
                    "SERPRO_CPF_IRREGULAR"
                    if not cpf_regular
                    else "SERPRO_SIMILARITY_BELOW_THRESHOLD"
                )
            )
        )
        return SerproBiometricResult(
            passed=passed,
            similarity=round(similarity, 4),
            cpf_regular=cpf_regular,
            active_external_mtls=True,
            mode="SERPRO_MTLS_LIVE",
            circuit_state=self.circuit_state,
            reason_code=reason,
        )
