"""Deterministic Cryptographic Document Validator: VIO QR (CMS/PKCS#7, ICP-Brasil X.509) & ICAO 9303 NFC."""

from __future__ import annotations

import base64
from datetime import datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import re
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union
import zlib

from asn1crypto import cms, core
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.asymmetric.utils import (
    decode_dss_signature,
    encode_dss_signature,
)
import cv2
import numpy as np
from pydantic import BaseModel, Field

try:
    import zxingcpp  # Industrial C++ decoder for high-density VIO QR Codes (Version 15-25)
except ImportError:  # pragma: no cover
    zxingcpp = None


class ZipBombDetectedError(ValueError):
    """Raised when compressed QR/VIO payload exceeds safe decompression ceiling."""


class DataGroupHash(core.Sequence):
    """ICAO Doc 9303 ASN.1 DataGroupHash structure inside LDSSecurityObject."""

    _fields = [
        ("data_group_number", core.Integer),
        ("data_group_hash_value", core.OctetString),
    ]


class DataGroupHashValues(core.SequenceOf):
    _child_spec = DataGroupHash


class AlgorithmIdentifierSimple(core.Sequence):
    _fields = [
        ("algorithm", core.ObjectIdentifier),
        ("parameters", core.Any, {"optional": True}),
    ]


class LDSSecurityObject(core.Sequence):
    """ICAO Doc 9303 ASN.1 LDSSecurityObject (EF.SOD encapsulated content)."""

    _fields = [
        ("version", core.Integer),
        ("hash_algorithm", AlgorithmIdentifierSimple),
        ("data_group_hash_values", DataGroupHashValues),
    ]


class VioValidationResult(BaseModel):
    """Outcome of VIO QR optical decoding, CMS/PKCS#7 verification, X.509 chain & Anti-Cloning check."""

    valid: bool
    reason_code: str
    signature_valid: bool = False
    cert_chain_valid: bool = False
    cloning_detected: bool = False
    zip_bomb_blocked: bool = False
    extracted_cpf: Optional[str] = None
    extracted_name: Optional[str] = None
    issuer_subject_dn: Optional[str] = None
    attributes: Dict[str, Any] = Field(default_factory=dict)


class NfcPassiveAuthResult(BaseModel):
    """Outcome of ICAO Doc 9303 Passive Authentication over EF.SOD + DG1 (MRZ) + DG2 (Face)."""

    valid: bool
    reason_code: str
    cms_signature_valid: bool = False
    cert_chain_valid: bool = False
    dg1_hash_matched: bool = False
    dg2_hash_matched: bool = False
    signer_subject_dn: Optional[str] = None


def ieee_p1363_to_der_signature(raw_rs: bytes, coord_size: int = 32) -> bytes:
    """Converts fixed-width ECDSA IEEE P1363 (r || s) signature into ASN.1 DER ECDSA-Sig-Value."""
    if len(raw_rs) != coord_size * 2:
        raise ValueError(
            f"Assinatura IEEE P1363 inválida: esperado {coord_size * 2} bytes, recebido {len(raw_rs)}."
        )
    r = int.from_bytes(raw_rs[:coord_size], byteorder="big")
    s = int.from_bytes(raw_rs[coord_size:], byteorder="big")
    if r <= 0 or s <= 0:
        raise ValueError("Componentes ECDSA (r, s) devem ser inteiros positivos.")
    return encode_dss_signature(r, s)


def der_to_ieee_p1363_signature(der_sig: bytes, coord_size: int = 32) -> bytes:
    """Converts ASN.1 DER ECDSA-Sig-Value into fixed-width IEEE P1363 (r || s) bytes."""
    r, s = decode_dss_signature(der_sig)
    return r.to_bytes(coord_size, byteorder="big") + s.to_bytes(
        coord_size, byteorder="big"
    )


def _clean_digits(value: Optional[str]) -> str:
    return "".join(ch for ch in (value or "") if ch.isdigit())


def _hash_algo_from_name(name: str) -> hashes.HashAlgorithm:
    norm = (name or "sha256").lower().replace("-", "").replace("_", "")
    if norm in {"sha256", "2.16.840.1.101.3.4.2.1"}:
        return hashes.SHA256()
    if norm in {"sha384", "2.16.840.1.101.3.4.2.2"}:
        return hashes.SHA384()
    if norm in {"sha512", "2.16.840.1.101.3.4.2.3"}:
        return hashes.SHA512()
    raise ValueError(f"Algoritmo de hash não suportado ou inseguro: {name}")


def _hashlib_digest(data: bytes, algo_name: str) -> bytes:
    norm = (algo_name or "sha256").lower().replace("-", "").replace("_", "")
    if norm in {"sha256", "2.16.840.1.101.3.4.2.1"}:
        return hashlib.sha256(data).digest()
    if norm in {"sha384", "2.16.840.1.101.3.4.2.2"}:
        return hashlib.sha384(data).digest()
    if norm in {"sha512", "2.16.840.1.101.3.4.2.3"}:
        return hashlib.sha512(data).digest()
    raise ValueError(f"Algoritmo de hash não suportado ou inseguro: {algo_name}")


def _unwrap_icao_sod_tag_77(raw_der: bytes) -> bytes:
    """Unwraps ICAO Doc 9303 Application 23 tag (0x77) if present around CMS ContentInfo (0x30)."""
    if not raw_der or raw_der[0] != 0x77:
        return raw_der
    if len(raw_der) < 4:
        raise ValueError("EF.SOD truncado no cabeçalho TLV 0x77.")
    length_byte = raw_der[1]
    if length_byte < 0x80:
        offset = 2
        content_len = length_byte
    else:
        num_len_bytes = length_byte & 0x7F
        if num_len_bytes == 0 or num_len_bytes > 4 or len(raw_der) < 2 + num_len_bytes:
            raise ValueError("Comprimento BER/DER inválido no cabeçalho EF.SOD 0x77.")
        content_len = int.from_bytes(raw_der[2 : 2 + num_len_bytes], byteorder="big")
        offset = 2 + num_len_bytes
    if offset + content_len > len(raw_der):
        raise ValueError("Conteúdo EF.SOD truncado em relação ao TLV 0x77.")
    return raw_der[offset : offset + content_len]


class GovCryptographicDocumentValidator:
    """Deterministic Cryptographic Validator for VIO QR Codes (CNH/CIN) and ICAO 9303 NFC Chips."""

    def __init__(
        self,
        trust_store_dir: Union[str, Path] = "./certs/icp_brasil",
        *,
        trusted_roots: Optional[Sequence[x509.Certificate]] = None,
        max_decompressed_bytes: int = 65536,
    ) -> None:
        self.max_decompressed_bytes = int(max_decompressed_bytes)
        self.trusted_certs: List[x509.Certificate] = []
        if trusted_roots:
            for cert in trusted_roots:
                self.add_trusted_root(cert)

        cert_dir = Path(trust_store_dir)
        if cert_dir.exists() and cert_dir.is_dir():
            for ext in ("*.pem", "*.cer", "*.der", "*.crt"):
                for cert_file in sorted(cert_dir.glob(ext)):
                    try:
                        self.add_trusted_root(cert_file.read_bytes())
                    except Exception:
                        continue

    def add_trusted_root(
        self, cert_or_bytes: Union[x509.Certificate, bytes, str]
    ) -> x509.Certificate:
        """Registers a trusted X.509 Root/Intermediate CA certificate programmatically."""
        if isinstance(cert_or_bytes, x509.Certificate):
            cert = cert_or_bytes
        else:
            raw = (
                cert_or_bytes.encode("utf-8")
                if isinstance(cert_or_bytes, str)
                else bytes(cert_or_bytes)
            )
            if b"-----BEGIN CERTIFICATE-----" in raw:
                cert = x509.load_pem_x509_certificate(raw)
            else:
                cert = x509.load_der_x509_certificate(raw)

        fp = cert.fingerprint(hashes.SHA256())
        if not any(existing.fingerprint(hashes.SHA256()) == fp for existing in self.trusted_certs):
            self.trusted_certs.append(cert)
        return cert

    @staticmethod
    def _decode_high_density_qr(qr_crop_png_bytes: bytes) -> Optional[bytes]:
        """Applies 2x bicubic upscaling + CLAHE (2.2, 8x8) + Gaussian threshold and decodes via zxingcpp/OpenCV."""
        if not qr_crop_png_bytes:
            return None
        arr = np.frombuffer(qr_crop_png_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
        if img is None or img.size == 0:
            return None

        upscaled = cv2.resize(img, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
        clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(8, 8)).apply(upscaled)
        adaptive = cv2.adaptiveThreshold(
            clahe,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            7,
        )
        candidates = [upscaled, clahe, adaptive, img]

        if zxingcpp is not None:
            for candidate in candidates:
                try:
                    barcodes = zxingcpp.read_barcodes(
                        candidate,
                        formats=zxingcpp.BarcodeFormat.QRCode,
                        try_rotate=True,
                        try_downscale=True,
                        try_invert=True,
                    )
                except TypeError:
                    barcodes = zxingcpp.read_barcodes(candidate)
                for bc in barcodes:
                    if getattr(bc, "valid", True):
                        raw_bytes = getattr(bc, "bytes", b"")
                        if raw_bytes:
                            return bytes(raw_bytes)
                        if bc.text:
                            return bc.text.encode("latin1", errors="ignore")

        detector = cv2.QRCodeDetector()
        for candidate in candidates:
            decoded_text, _, _ = detector.detectAndDecode(candidate)
            if decoded_text:
                return decoded_text.encode("latin1", errors="ignore")

        return None

    def safe_zlib_decompress(
        self, compressed_bytes: bytes, max_length: Optional[int] = None
    ) -> bytes:
        """Decompresses zlib/deflate stream safely, deterministically blocking zip-bombs (>64 KiB)."""
        limit = int(max_length if max_length is not None else self.max_decompressed_bytes)
        if not compressed_bytes:
            raise ValueError("Stream comprimido vazio.")

        last_err: Optional[Exception] = None
        for wbits in (zlib.MAX_WBITS, -zlib.MAX_WBITS):
            try:
                decomp = zlib.decompressobj(wbits)
                chunk = decomp.decompress(compressed_bytes, max_length=limit)
                if decomp.unconsumed_tail:
                    raise ZipBombDetectedError(
                        f"VIO_ZIP_BOMB_DETECTED: Descompressão excedeu o limite seguro de {limit} bytes."
                    )
                remaining_budget = max(0, limit - len(chunk))
                flushed = decomp.flush(remaining_budget + 1)
                if len(chunk) + len(flushed) > limit or not decomp.eof:
                    raise ZipBombDetectedError(
                        f"VIO_ZIP_BOMB_DETECTED: Flush excedeu o limite seguro de {limit} bytes."
                    )
                return chunk + flushed
            except ZipBombDetectedError:
                raise
            except zlib.error as exc:
                last_err = exc
                continue

        raise ValueError(f"Payload zlib inválido ou corrompido: {last_err}")

    @staticmethod
    def _is_zlib_header(data: bytes) -> bool:
        return (
            len(data) >= 2
            and data[0] == 0x78
            and data[1] in (0x01, 0x5E, 0x9C, 0xDA)
        )

    def _verify_x509_chain(
        self,
        leaf_cert: x509.Certificate,
        intermediate_pool: Sequence[x509.Certificate],
        now_utc: datetime,
    ) -> bool:
        """Validates RFC 5280 validity window, KeyUsage, BasicConstraints/path_length & signature chain."""
        if not self.trusted_certs:
            return False

        trusted_by_fp = {
            c.fingerprint(hashes.SHA256()): c for c in self.trusted_certs
        }

        def _within_validity(cert: x509.Certificate) -> bool:
            return cert.not_valid_before_utc <= now_utc <= cert.not_valid_after_utc

        def _check_leaf_key_usage(cert: x509.Certificate) -> bool:
            try:
                ku = cert.extensions.get_extension_for_class(x509.KeyUsage).value
                return bool(ku.digital_signature or ku.content_commitment)
            except x509.ExtensionNotFound:
                return True

        def _check_ca_constraints_and_key_usage(
            cert: x509.Certificate, intermediates_followed: int
        ) -> bool:
            try:
                bc = cert.extensions.get_extension_for_class(x509.BasicConstraints).value
                if not bc.ca:
                    return False
                if (
                    bc.path_length is not None
                    and bc.path_length < intermediates_followed
                ):
                    return False
            except x509.ExtensionNotFound:
                return False

            try:
                ku = cert.extensions.get_extension_for_class(x509.KeyUsage).value
                if not ku.key_cert_sign:
                    return False
            except x509.ExtensionNotFound:
                pass
            return True

        if not _within_validity(leaf_cert) or not _check_leaf_key_usage(leaf_cert):
            return False

        # Direct trust if leaf itself is explicitly pinned and valid
        leaf_fp = leaf_cert.fingerprint(hashes.SHA256())
        if leaf_fp in trusted_by_fp:
            try:
                if leaf_cert.issuer == leaf_cert.subject:
                    leaf_cert.verify_directly_issued_by(leaf_cert)
                return True
            except Exception:
                return False

        all_candidates: List[x509.Certificate] = list(intermediate_pool) + list(
            self.trusted_certs
        )
        current = leaf_cert
        visited = {leaf_fp}
        intermediate_ca_count = 0

        for _depth in range(8):
            matching_issuers = [
                cand for cand in all_candidates if cand.subject == current.issuer
            ]
            if not matching_issuers:
                return False

            verified_parent: Optional[x509.Certificate] = None
            for parent in matching_issuers:
                if not _within_validity(parent):
                    continue
                if not _check_ca_constraints_and_key_usage(parent, intermediate_ca_count):
                    continue
                try:
                    current.verify_directly_issued_by(parent)
                    verified_parent = parent
                    break
                except Exception:
                    continue

            if verified_parent is None:
                return False

            parent_fp = verified_parent.fingerprint(hashes.SHA256())
            if parent_fp in trusted_by_fp:
                if verified_parent.issuer == verified_parent.subject:
                    try:
                        verified_parent.verify_directly_issued_by(verified_parent)
                    except Exception:
                        return False
                return True

            if parent_fp in visited:
                return False
            visited.add(parent_fp)
            if verified_parent.issuer != verified_parent.subject:
                intermediate_ca_count += 1
            current = verified_parent

        return False

    @staticmethod
    def _verify_asymmetric_signature(
        public_key: Any,
        signature_bytes: bytes,
        signed_payload: bytes,
        sig_algo_name: str,
        hash_algo_name: str,
        sig_algo_params: Optional[Any] = None,
    ) -> bool:
        """Verifies ECDSA P-256/P-384 (both IEEE P1363 r||s and ASN.1 DER) and RSA PKCS#1 v1.5 / RSA-PSS."""
        hash_alg = _hash_algo_from_name(hash_algo_name)

        if isinstance(public_key, ec.EllipticCurvePublicKey):
            coord_size = (public_key.key_size + 7) // 8
            der_candidates: List[bytes] = []
            if len(signature_bytes) == coord_size * 2 and (
                not signature_bytes.startswith(b"\x30")
                or signature_bytes[1] != len(signature_bytes) - 2
            ):
                try:
                    der_candidates.append(
                        ieee_p1363_to_der_signature(signature_bytes, coord_size=coord_size)
                    )
                except ValueError:
                    pass
            der_candidates.append(signature_bytes)
            if len(signature_bytes) == coord_size * 2:
                try:
                    der_candidates.append(
                        ieee_p1363_to_der_signature(signature_bytes, coord_size=coord_size)
                    )
                except ValueError:
                    pass

            for der_sig in der_candidates:
                try:
                    public_key.verify(der_sig, signed_payload, ec.ECDSA(hash_alg))
                    return True
                except InvalidSignature:
                    continue
                except Exception:
                    continue
            return False

        if isinstance(public_key, rsa.RSAPublicKey):
            algo_lower = (sig_algo_name or "").lower()
            is_pss = "pss" in algo_lower or algo_lower == "1.2.840.113549.1.1.10"
            if is_pss:
                salt_len: Any = padding.PSS.AUTO
                if sig_algo_params is not None and hasattr(sig_algo_params, "native"):
                    native_params = sig_algo_params.native
                    if isinstance(native_params, dict) and "salt_length" in native_params:
                        salt_len = int(native_params["salt_length"])
                try:
                    public_key.verify(
                        signature_bytes,
                        signed_payload,
                        padding.PSS(mgf=padding.MGF1(hash_alg), salt_length=salt_len),
                        hash_alg,
                    )
                    return True
                except InvalidSignature:
                    return False
            else:
                try:
                    public_key.verify(
                        signature_bytes,
                        signed_payload,
                        padding.PKCS1v15(),
                        hash_alg,
                    )
                    return True
                except InvalidSignature:
                    return False

        return False

    def _verify_cms_signed_data(
        self, cms_der: bytes, now_utc: datetime
    ) -> Tuple[bool, bool, bytes, Optional[str], str]:
        """
        Parses and cryptographically verifies an ASN.1 DER CMS / PKCS#7 SignedData envelope.
        Returns: (signature_ok, chain_ok, encapsulated_bytes, signer_subject_dn, reason_code)
        """
        try:
            content_info = cms.ContentInfo.load(cms_der)
            if content_info["content_type"].native != "signed_data":
                return False, False, b"", None, "CMS_NOT_SIGNED_DATA"
            signed_data = content_info["content"]
        except Exception:
            return False, False, b"", None, "CMS_ASN1_PARSE_ERROR"

        embedded_certs: List[x509.Certificate] = []
        if signed_data["certificates"] is not None and not isinstance(
            signed_data["certificates"], core.Void
        ):
            for cert_choice in signed_data["certificates"]:
                if cert_choice.name == "certificate":
                    try:
                        embedded_certs.append(
                            x509.load_der_x509_certificate(cert_choice.chosen.dump())
                        )
                    except Exception:
                        continue

        encap_info = signed_data["encap_content_info"]
        if encap_info["content"] is None or isinstance(
            encap_info["content"], core.Void
        ):
            return False, False, b"", None, "CMS_EMPTY_ENCAP_CONTENT"
        raw_encap_bytes = bytes(encap_info["content"].contents)
        # Note: in asn1crypto, ParsableOctetString.native is bytes, while .contents is raw octets
        if isinstance(encap_info["content"].native, bytes):
            raw_encap_bytes = encap_info["content"].native

        signer_infos = signed_data["signer_infos"]
        if len(signer_infos) == 0:
            return False, False, raw_encap_bytes, None, "CMS_NO_SIGNER_INFO"

        signer_info = signer_infos[0]
        digest_algo_name = signer_info["digest_algorithm"]["algorithm"].native
        sig_algo_obj = signer_info["signature_algorithm"]
        sig_algo_name = sig_algo_obj["algorithm"].native
        sig_algo_params = sig_algo_obj["parameters"]
        signature_bytes = signer_info["signature"].native

        # Resolve signer certificate via issuer_and_serial_number or SKI
        sid = signer_info["sid"]
        signer_cert: Optional[x509.Certificate] = None
        search_pool = embedded_certs + self.trusted_certs
        if sid.name == "issuer_and_serial_number":
            target_serial = sid.chosen["serial_number"].native
            for cand in search_pool:
                if cand.serial_number == target_serial:
                    signer_cert = cand
                    break
        elif sid.name == "subject_key_identifier":
            target_ski = sid.chosen.native
            for cand in search_pool:
                try:
                    ski_ext = cand.extensions.get_extension_for_class(
                        x509.SubjectKeyIdentifier
                    )
                    if ski_ext.value.digest == target_ski:
                        signer_cert = cand
                        break
                except x509.ExtensionNotFound:
                    continue

        if signer_cert is None and embedded_certs:
            signer_cert = embedded_certs[0]
        if signer_cert is None:
            return False, False, raw_encap_bytes, None, "CMS_SIGNER_CERT_NOT_FOUND"

        signer_dn = signer_cert.subject.rfc4514_string()
        chain_ok = self._verify_x509_chain(signer_cert, embedded_certs, now_utc)

        # SignedAttributes verification (RFC 5652 Section 5.4)
        signed_attrs = signer_info["signed_attrs"]
        if signed_attrs is not None and not isinstance(signed_attrs, core.Void) and len(signed_attrs) > 0:
            attr_digest: Optional[bytes] = None
            attr_content_type: Optional[str] = None
            for attr in signed_attrs:
                attr_type = attr["type"].native
                if attr_type == "message_digest" and len(attr["values"]) > 0:
                    val = attr["values"][0].native
                    if isinstance(val, bytes):
                        attr_digest = val
                elif attr_type == "content_type" and len(attr["values"]) > 0:
                    attr_content_type = str(attr["values"][0].native)
            if (
                attr_content_type is not None
                and attr_content_type != str(encap_info["content_type"].native)
            ):
                return False, chain_ok, raw_encap_bytes, signer_dn, "CMS_CONTENT_TYPE_ATTR_MISMATCH"
            if attr_digest is None:
                return False, chain_ok, raw_encap_bytes, signer_dn, "CMS_MISSING_MESSAGE_DIGEST_ATTR"

            computed_digest = _hashlib_digest(raw_encap_bytes, digest_algo_name)
            if not hmac.compare_digest(computed_digest, attr_digest):
                return False, chain_ok, raw_encap_bytes, signer_dn, "CMS_MESSAGE_DIGEST_MISMATCH"

            # Replace IMPLICIT [0] tag (0xA0) with EXPLICIT SET OF (0x31) for signature input
            dumped_attrs = signed_attrs.dump()
            signed_payload = b"\x31" + dumped_attrs[1:]
        else:
            signed_payload = raw_encap_bytes

        sig_ok = self._verify_asymmetric_signature(
            public_key=signer_cert.public_key(),
            signature_bytes=signature_bytes,
            signed_payload=signed_payload,
            sig_algo_name=sig_algo_name,
            hash_algo_name=digest_algo_name,
            sig_algo_params=sig_algo_params,
        )
        if not sig_ok:
            return False, chain_ok, raw_encap_bytes, signer_dn, "CMS_SIGNATURE_INVALID"
        if not chain_ok:
            return True, False, raw_encap_bytes, signer_dn, "X509_TRUST_CHAIN_INVALID"
        return True, True, raw_encap_bytes, signer_dn, "OK"

    def _normalize_raw_vio_bytes(self, raw_qr_bytes: bytes) -> bytes:
        """Unwraps Base64/Hex ASCII framing and applies anti-zip-bomb decompression if outer layer is zlib."""
        if not raw_qr_bytes:
            return b""
        # Never call .strip() on raw binary ASN.1 DER or raw binary zlib streams (preserves trailing 0x09..0x20 octets)
        if raw_qr_bytes.startswith(b"\x30"):
            return raw_qr_bytes
        if self._is_zlib_header(raw_qr_bytes):
            return self.safe_zlib_decompress(raw_qr_bytes)

        payload = raw_qr_bytes
        if payload.startswith(b"VIO1:"):
            payload = payload[5:]
            if payload.startswith(b"\x30"):
                return payload
            if self._is_zlib_header(payload):
                return self.safe_zlib_decompress(payload)

        payload = payload.strip()
        if payload.startswith(b"VIO1:"):
            payload = payload[5:].strip()

        if self._is_zlib_header(payload):
            return self.safe_zlib_decompress(payload)

        # If ASCII base64/hex encoded binary envelope
        if payload and not payload.startswith((b"\x30", b"{")):
            try:
                ascii_str = payload.decode("ascii").strip()
                if re.fullmatch(r"[0-9A-Fa-f]+", ascii_str) and len(ascii_str) % 2 == 0:
                    decoded = bytes.fromhex(ascii_str)
                else:
                    padded = ascii_str + ("=" * ((4 - len(ascii_str) % 4) % 4))
                    decoded = base64.urlsafe_b64decode(padded)
                if self._is_zlib_header(decoded):
                    return self.safe_zlib_decompress(decoded)
                if decoded.startswith((b"\x30", b"{")):
                    return decoded
            except ZipBombDetectedError:
                raise
            except Exception:
                pass
        return payload

    @staticmethod
    def _extract_civil_attributes_from_payload(payload_bytes: bytes) -> Dict[str, Any]:
        """Extracts civil identity fields (cpf, name, renach, doc_number) from JSON or structured VIO text."""
        text = payload_bytes.decode("utf-8", errors="replace").strip()
        if text.startswith("{"):
            data = json.loads(text)
            if isinstance(data, dict):
                return data

        attrs: Dict[str, Any] = {}
        for part in re.split(r"[|;\n]", text):
            if "=" in part:
                k, v = part.split("=", 1)
                attrs[k.strip().lower()] = v.strip()
            elif ":" in part:
                k, v = part.split(":", 1)
                attrs[k.strip().lower()] = v.strip()
        return attrs

    def validate_vio_payload_bytes(
        self,
        raw_qr_bytes: bytes,
        *,
        ocr_cpf: str,
        typed_cpf: str,
        now_utc: Optional[datetime] = None,
    ) -> VioValidationResult:
        """Validates raw decoded VIO QR payload (CMS/PKCS#7 DER or Compact VIO Envelope) & Anti-Cloning Lock."""
        eval_now = now_utc or datetime.now(timezone.utc)
        try:
            normalized = self._normalize_raw_vio_bytes(raw_qr_bytes)
        except ZipBombDetectedError:
            return VioValidationResult(
                valid=False,
                reason_code="VIO_ZIP_BOMB_BLOCKED",
                zip_bomb_blocked=True,
            )
        except Exception:
            return VioValidationResult(
                valid=False,
                reason_code="VIO_DECODE_OR_DECOMPRESS_FAILED",
            )

        sig_ok = False
        chain_ok = False
        signer_dn: Optional[str] = None
        inner_payload_bytes = b""

        if normalized.startswith(b"\x30"):
            sig_ok, chain_ok, encap_bytes, signer_dn, reason = (
                self._verify_cms_signed_data(normalized, eval_now)
            )
            if not sig_ok or not chain_ok:
                return VioValidationResult(
                    valid=False,
                    reason_code=reason,
                    signature_valid=sig_ok,
                    cert_chain_valid=chain_ok,
                    issuer_subject_dn=signer_dn,
                )
            try:
                inner_payload_bytes = (
                    self.safe_zlib_decompress(encap_bytes)
                    if self._is_zlib_header(encap_bytes)
                    else encap_bytes
                )
            except ZipBombDetectedError:
                return VioValidationResult(
                    valid=False,
                    reason_code="VIO_ZIP_BOMB_BLOCKED",
                    signature_valid=sig_ok,
                    cert_chain_valid=chain_ok,
                    zip_bomb_blocked=True,
                    issuer_subject_dn=signer_dn,
                )
        elif normalized.startswith(b"{"):
            # Compact signed VIO JSON envelope
            try:
                env_obj = json.loads(normalized.decode("utf-8"))
                cert_der = base64.b64decode(env_obj["cert_der_b64"])
                sig_bytes = base64.b64decode(env_obj["signature_b64"])
                signed_blob = base64.b64decode(env_obj["payload_b64"])
                alg = str(env_obj.get("alg", "ES256")).upper()
            except Exception:
                return VioValidationResult(
                    valid=False, reason_code="VIO_COMPACT_ENVELOPE_MALFORMED"
                )

            try:
                signer_cert = x509.load_der_x509_certificate(cert_der)
            except Exception:
                return VioValidationResult(
                    valid=False, reason_code="VIO_COMPACT_CERT_INVALID"
                )

            signer_dn = signer_cert.subject.rfc4514_string()
            chain_ok = self._verify_x509_chain(signer_cert, [], eval_now)
            sig_algo_hint = "rsassa_pss" if alg == "PS256" else alg
            sig_ok = self._verify_asymmetric_signature(
                public_key=signer_cert.public_key(),
                signature_bytes=sig_bytes,
                signed_payload=signed_blob,
                sig_algo_name=sig_algo_hint,
                hash_algo_name="sha256",
            )
            if not sig_ok:
                return VioValidationResult(
                    valid=False,
                    reason_code="CMS_SIGNATURE_INVALID",
                    signature_valid=False,
                    cert_chain_valid=chain_ok,
                    issuer_subject_dn=signer_dn,
                )
            if not chain_ok:
                return VioValidationResult(
                    valid=False,
                    reason_code="X509_TRUST_CHAIN_INVALID",
                    signature_valid=True,
                    cert_chain_valid=False,
                    issuer_subject_dn=signer_dn,
                )
            try:
                inner_payload_bytes = (
                    self.safe_zlib_decompress(signed_blob)
                    if self._is_zlib_header(signed_blob)
                    else signed_blob
                )
            except ZipBombDetectedError:
                return VioValidationResult(
                    valid=False,
                    reason_code="VIO_ZIP_BOMB_BLOCKED",
                    signature_valid=True,
                    cert_chain_valid=True,
                    zip_bomb_blocked=True,
                    issuer_subject_dn=signer_dn,
                )
        else:
            return VioValidationResult(
                valid=False, reason_code="UNSUPPORTED_VIO_PAYLOAD_FORMAT"
            )

        try:
            attrs = self._extract_civil_attributes_from_payload(inner_payload_bytes)
        except Exception:
            return VioValidationResult(
                valid=False,
                reason_code="VIO_PAYLOAD_ATTRIBUTES_CORRUPTED",
                signature_valid=sig_ok,
                cert_chain_valid=chain_ok,
                issuer_subject_dn=signer_dn,
            )

        qr_cpf = _clean_digits(
            str(attrs.get("cpf") or attrs.get("cpf_11_digits") or "")
        )
        qr_name = str(
            attrs.get("name") or attrs.get("nome") or attrs.get("full_name") or ""
        ).strip() or None
        clean_ocr_cpf = _clean_digits(ocr_cpf)
        clean_typed_cpf = _clean_digits(typed_cpf)

        if len(qr_cpf) != 11:
            return VioValidationResult(
                valid=False,
                reason_code="VIO_MISSING_SIGNED_CPF",
                signature_valid=sig_ok,
                cert_chain_valid=chain_ok,
                issuer_subject_dn=signer_dn,
                attributes=attrs,
            )

        # Bit-for-Bit Anti-Cloning Lock: qr_cpf == ocr_cpf == typed_cpf
        if qr_cpf != clean_ocr_cpf or qr_cpf != clean_typed_cpf:
            return VioValidationResult(
                valid=False,
                reason_code="VIO_CPF_CLONING_MISMATCH",
                signature_valid=sig_ok,
                cert_chain_valid=chain_ok,
                cloning_detected=True,
                extracted_cpf=qr_cpf,
                extracted_name=qr_name,
                issuer_subject_dn=signer_dn,
                attributes=attrs,
            )

        return VioValidationResult(
            valid=True,
            reason_code="OK",
            signature_valid=True,
            cert_chain_valid=True,
            cloning_detected=False,
            extracted_cpf=qr_cpf,
            extracted_name=qr_name,
            issuer_subject_dn=signer_dn,
            attributes=attrs,
        )

    def validate_vio_qr_crop(
        self,
        qr_crop_png_bytes: bytes,
        *,
        ocr_cpf: str,
        typed_cpf: str,
        now_utc: Optional[datetime] = None,
    ) -> VioValidationResult:
        """Full optical + cryptographic validation pipeline over the lossless PNG crop from Argon High."""
        decoded = self._decode_high_density_qr(qr_crop_png_bytes)
        if not decoded:
            return VioValidationResult(
                valid=False, reason_code="QR_OPTICAL_DECODE_FAILED"
            )
        return self.validate_vio_payload_bytes(
            decoded,
            ocr_cpf=ocr_cpf,
            typed_cpf=typed_cpf,
            now_utc=now_utc,
        )

    def validate_nfc_passive_auth(
        self,
        ef_sod_der: bytes,
        dg1_bytes: bytes,
        dg2_bytes: bytes,
        *,
        now_utc: Optional[datetime] = None,
    ) -> NfcPassiveAuthResult:
        """
        ICAO Doc 9303 Passive Authentication for Nova CIN and e-Passports:
        1) Unwraps EF.SOD (tag 0x77 if present) and verifies CMS SignedData against DS -> CSCA chain;
        2) Parses LDSSecurityObject and recalculates SHA-256 digests of DG1 (MRZ) and DG2 (Face ISO 19794-5).
        """
        eval_now = now_utc or datetime.now(timezone.utc)
        if not ef_sod_der or not dg1_bytes or not dg2_bytes:
            return NfcPassiveAuthResult(
                valid=False, reason_code="NFC_MISSING_SOD_OR_DATAGROUPS"
            )

        try:
            cms_der = _unwrap_icao_sod_tag_77(ef_sod_der)
        except ValueError:
            return NfcPassiveAuthResult(valid=False, reason_code="NFC_SOD_TLV_MALFORMED")

        sig_ok, chain_ok, lds_bytes, signer_dn, reason = self._verify_cms_signed_data(
            cms_der, eval_now
        )
        if not sig_ok or not chain_ok:
            return NfcPassiveAuthResult(
                valid=False,
                reason_code=f"NFC_{reason}",
                cms_signature_valid=sig_ok,
                cert_chain_valid=chain_ok,
                signer_subject_dn=signer_dn,
            )

        dg_hashes: Dict[int, bytes] = {}
        hash_alg_oid_or_name = "sha256"

        try:
            lds_obj = LDSSecurityObject.load(lds_bytes)
            hash_alg_oid_or_name = lds_obj["hash_algorithm"]["algorithm"].native
            for item in lds_obj["data_group_hash_values"]:
                dg_num = int(item["data_group_number"].native)
                dg_val = bytes(item["data_group_hash_value"].native)
                dg_hashes[dg_num] = dg_val
        except Exception:
            return NfcPassiveAuthResult(
                valid=False,
                reason_code="NFC_LDS_SECURITY_OBJECT_MALFORMED",
                cms_signature_valid=True,
                cert_chain_valid=True,
                signer_subject_dn=signer_dn,
            )

        if 1 not in dg_hashes or 2 not in dg_hashes:
            return NfcPassiveAuthResult(
                valid=False,
                reason_code="NFC_MISSING_DG1_OR_DG2_HASH",
                cms_signature_valid=True,
                cert_chain_valid=True,
                signer_subject_dn=signer_dn,
            )

        actual_dg1_hash = _hashlib_digest(dg1_bytes, hash_alg_oid_or_name)
        actual_dg2_hash = _hashlib_digest(dg2_bytes, hash_alg_oid_or_name)

        dg1_ok = hmac.compare_digest(actual_dg1_hash, dg_hashes[1])
        dg2_ok = hmac.compare_digest(actual_dg2_hash, dg_hashes[2])

        if not dg1_ok:
            return NfcPassiveAuthResult(
                valid=False,
                reason_code="NFC_DG1_MRZ_HASH_MISMATCH",
                cms_signature_valid=True,
                cert_chain_valid=True,
                dg1_hash_matched=False,
                dg2_hash_matched=dg2_ok,
                signer_subject_dn=signer_dn,
            )
        if not dg2_ok:
            return NfcPassiveAuthResult(
                valid=False,
                reason_code="NFC_DG2_FACE_HASH_MISMATCH",
                cms_signature_valid=True,
                cert_chain_valid=True,
                dg1_hash_matched=True,
                dg2_hash_matched=False,
                signer_subject_dn=signer_dn,
            )

        return NfcPassiveAuthResult(
            valid=True,
            reason_code="OK",
            cms_signature_valid=True,
            cert_chain_valid=True,
            dg1_hash_matched=True,
            dg2_hash_matched=True,
            signer_subject_dn=signer_dn,
        )
