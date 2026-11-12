import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'perceptual_hash_guard.dart';

/// Origem física do frame de captura no fluxo forense de KYC/Vistoria.
///
/// No modo forense, apenas [CaptureOrigin.liveCameraOnly] é permitido.
/// Qualquer tentativa de upload estático de galeria ou arquivo
/// ([CaptureOrigin.galleryOrFileBlocked]) é bloqueada deterministicamente.
enum CaptureOrigin {
  liveCameraOnly,
  galleryOrFileBlocked;

  String get wireCode => switch (this) {
        CaptureOrigin.liveCameraOnly => 'LIVE_CAMERA',
        CaptureOrigin.galleryOrFileBlocked => 'GALLERY_UPLOAD_BLOCKED',
      };
}

/// Veredito de integridade de hardware/ambiente coletado no cliente.
enum DeviceIntegrityVerdict {
  meetsStrongIntegrity,
  appAttestHardware,
  homologationOrPwaLimited,
  virtualCameraBlocked,
  untrustedDevice;

  String get wireCode => switch (this) {
        DeviceIntegrityVerdict.meetsStrongIntegrity => 'MEETS_STRONG_INTEGRITY',
        DeviceIntegrityVerdict.appAttestHardware => 'APP_ATTEST_HARDWARE',
        DeviceIntegrityVerdict.homologationOrPwaLimited => 'WEB_LIMITED_ALCADA',
        DeviceIntegrityVerdict.virtualCameraBlocked => 'UNTRUSTED',
        DeviceIntegrityVerdict.untrustedDevice => 'UNTRUSTED',
      };
}

/// Metadados estruturados de integridade do dispositivo e câmera física.
class DeviceIntegrityMetadata {
  final DeviceIntegrityVerdict verdict;
  final String attestationProvider;
  final String? attestationToken;
  final List<String> detectedCameraLabels;
  final bool hasSuspiciousVirtualCamera;
  final String? suspiciousCameraReason;

  const DeviceIntegrityMetadata({
    required this.verdict,
    required this.attestationProvider,
    this.attestationToken,
    this.detectedCameraLabels = const <String>[],
    required this.hasSuspiciousVirtualCamera,
    this.suspiciousCameraReason,
  });

  bool get isAllowedForKyc =>
      !hasSuspiciousVirtualCamera &&
      verdict != DeviceIntegrityVerdict.virtualCameraBlocked &&
      verdict != DeviceIntegrityVerdict.untrustedDevice;

  bool get isHomologationFallback =>
      verdict == DeviceIntegrityVerdict.homologationOrPwaLimited;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'verdict': verdict.name,
        'attestation_verdict': verdict.wireCode,
        'attestation_provider': attestationProvider,
        if (attestationToken != null) 'attestation_token': attestationToken,
        'detected_camera_labels': detectedCameraLabels,
        'has_suspicious_virtual_camera': hasSuspiciousVirtualCamera,
        if (suspiciousCameraReason != null)
          'suspicious_camera_reason': suspiciousCameraReason,
      };
}

/// Interface plugável para coleta de Play Integrity (Android) / App Attest (iOS).
abstract class DeviceIntegrityAttestationProvider {
  Future<DeviceIntegrityMetadata> collectIntegrityMetadata({
    required String sessionNonce,
    List<String> cameraLabels = const <String>[],
  });
}

/// Provedor padrão de integridade com detecção heurística de câmeras virtuais
/// e fallback controlado `homologation_or_pwa_limited` para Web/PWA/testes
/// quando credenciais nativas não estão presentes.
class DefaultDeviceIntegrityAttestationProvider
    implements DeviceIntegrityAttestationProvider {
  final DeviceIntegrityVerdict? nativeVerdictOverride;
  final String? nativeTokenOverride;
  final String providerLabel;

  const DefaultDeviceIntegrityAttestationProvider({
    this.nativeVerdictOverride,
    this.nativeTokenOverride,
    this.providerLabel = 'homologation_or_pwa_limited',
  });

  @override
  Future<DeviceIntegrityMetadata> collectIntegrityMetadata({
    required String sessionNonce,
    List<String> cameraLabels = const <String>[],
  }) async {
    return KycSessionAntiSwapGuard.evaluateDeviceIntegrity(
      cameraLabels: cameraLabels,
      nativeVerdictOverride: nativeVerdictOverride,
      nativeTokenOverride: nativeTokenOverride,
      providerLabel: providerLabel,
    );
  }
}

/// Selfie Canônica congelada no exato milissegundo da aprovação da Prova de Vida.
class FrozenCanonicalSelfie {
  final String selfieSha256;
  final int selfieDHash64;
  final String selfieDHashHex;
  final DateTime capturedAtUtc;
  final CaptureOrigin origin;

  const FrozenCanonicalSelfie({
    required this.selfieSha256,
    required this.selfieDHash64,
    required this.selfieDHashHex,
    required this.capturedAtUtc,
    required this.origin,
  });

  int get capturedAtEpochSec => capturedAtUtc.millisecondsSinceEpoch ~/ 1000;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'selfie_sha256': selfieSha256,
        'selfie_dhash_hex': selfieDHashHex,
        'captured_at_utc': capturedAtUtc.toIso8601String(),
        'captured_at_epoch_sec': capturedAtEpochSec,
        'origin': origin.name,
        'capture_source': origin.wireCode,
      };
}

/// Ticket imutável de vínculo criptográfico da sessão de KYC Anti-Swap.
class KycSessionBindingTicket {
  final String userId;
  final String sessionNonce;
  final DateTime issuedAtUtc;
  final int ttlSeconds;
  final FrozenCanonicalSelfie? frozenSelfie;
  final String? frontDocSha256;
  final String? backDocSha256;
  final int? frontDocDHash64;
  final int? backDocDHash64;
  final DateTime? docCapturedAtUtc;
  final String? requestHash;
  final DeviceIntegrityMetadata deviceIntegrity;

  const KycSessionBindingTicket({
    required this.userId,
    required this.sessionNonce,
    required this.issuedAtUtc,
    this.ttlSeconds = KycSessionAntiSwapGuard.maxSessionTtlSeconds,
    this.frozenSelfie,
    this.frontDocSha256,
    this.backDocSha256,
    this.frontDocDHash64,
    this.backDocDHash64,
    this.docCapturedAtUtc,
    this.requestHash,
    required this.deviceIntegrity,
  });

  DateTime get expiresAtUtc => issuedAtUtc.add(Duration(seconds: ttlSeconds));

  int get issuedAtEpochSec => issuedAtUtc.millisecondsSinceEpoch ~/ 1000;

  int? get docCapturedAtEpochSec => docCapturedAtUtc == null
      ? null
      : docCapturedAtUtc!.millisecondsSinceEpoch ~/ 1000;

  bool isExpired({DateTime? nowUtc}) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final elapsedSeconds = now.difference(issuedAtUtc).inSeconds;
    if (elapsedSeconds < 0 || elapsedSeconds > ttlSeconds) {
      return true;
    }
    if (frozenSelfie != null && docCapturedAtUtc != null) {
      final livenessToDocsSec =
          docCapturedAtUtc!.difference(frozenSelfie!.capturedAtUtc).inSeconds;
      if (livenessToDocsSec < 0 || livenessToDocsSec > ttlSeconds) {
        return true;
      }
    }
    return false;
  }

  int remainingSeconds({DateTime? nowUtc}) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final diff = expiresAtUtc.difference(now).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get hasFrozenSelfie => frozenSelfie != null;

  bool get isFullyBound =>
      frozenSelfie != null &&
      frontDocSha256 != null &&
      backDocSha256 != null &&
      docCapturedAtUtc != null &&
      requestHash != null &&
      requestHash!.length == 64 &&
      deviceIntegrity.isAllowedForKyc;

  KycSessionBindingTicket copyWith({
    String? userId,
    String? sessionNonce,
    DateTime? issuedAtUtc,
    int? ttlSeconds,
    FrozenCanonicalSelfie? frozenSelfie,
    String? frontDocSha256,
    String? backDocSha256,
    int? frontDocDHash64,
    int? backDocDHash64,
    DateTime? docCapturedAtUtc,
    String? requestHash,
    DeviceIntegrityMetadata? deviceIntegrity,
  }) {
    return KycSessionBindingTicket(
      userId: userId ?? this.userId,
      sessionNonce: sessionNonce ?? this.sessionNonce,
      issuedAtUtc: issuedAtUtc ?? this.issuedAtUtc,
      ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      frozenSelfie: frozenSelfie ?? this.frozenSelfie,
      frontDocSha256: frontDocSha256 ?? this.frontDocSha256,
      backDocSha256: backDocSha256 ?? this.backDocSha256,
      frontDocDHash64: frontDocDHash64 ?? this.frontDocDHash64,
      backDocDHash64: backDocDHash64 ?? this.backDocDHash64,
      docCapturedAtUtc: docCapturedAtUtc ?? this.docCapturedAtUtc,
      requestHash: requestHash ?? this.requestHash,
      deviceIntegrity: deviceIntegrity ?? this.deviceIntegrity,
    );
  }

  Map<String, dynamic> toAuditHeadersAndPayload() => <String, dynamic>{
        'user_id': userId,
        'session_nonce': sessionNonce,
        'issued_at_utc': issuedAtUtc.toIso8601String(),
        'ttl_seconds': ttlSeconds,
        'attestation_verdict': deviceIntegrity.verdict.wireCode,
        'capture_source':
            (frozenSelfie?.origin ?? CaptureOrigin.liveCameraOnly).wireCode,
        if (frozenSelfie != null) 'frozen_selfie': frozenSelfie!.toJson(),
        if (frontDocSha256 != null) 'front_doc_sha256': frontDocSha256,
        if (backDocSha256 != null) 'back_doc_sha256': backDocSha256,
        if (frontDocDHash64 != null)
          'front_doc_dhash_hex': PerceptualHashGuard.toHex64(frontDocDHash64!),
        if (backDocDHash64 != null)
          'back_doc_dhash_hex': PerceptualHashGuard.toHex64(backDocDHash64!),
        if (docCapturedAtUtc != null)
          'captured_at_epoch_sec': docCapturedAtEpochSec,
        if (requestHash != null) 'request_hash': requestHash,
        'device_integrity': deviceIntegrity.toJson(),
      };
}

/// Guardião client-side de Vínculo de Sessão Anti-Swap (`180s` TTL),
/// congelamento da Selfie Canônica e bloqueio de câmeras virtuais/galeria.
class KycSessionAntiSwapGuard {
  KycSessionAntiSwapGuard._();

  /// Janela máxima estrita entre emissão/prova de vida e submissão dos documentos.
  static const int maxSessionTtlSeconds = 180;

  /// Janela máxima estrita para conclusão da Prova de Vida após emissão do nonce (`90s`).
  static const int maxLivenessWindowSeconds = 90;

  /// Padrões conhecidos de drivers de injeção de câmera virtual / deepfake.
  static const List<String> bannedVirtualCameraTokens = <String>[
    'obs',
    'vcam',
    'virtualcam',
    'virtual camera',
    'manycam',
    'droidcam',
    'splitcam',
    'xsplit',
    'snap camera',
    'camtwist',
    'v4l2loopback',
    'fakecam',
    'youcam',
    'iriun',
    'epoccam',
  ];

  static final List<RegExp> _bannedVirtualCameraPatterns =
      bannedVirtualCameraTokens
          .map(
            (token) => RegExp(
              r'\b' + RegExp.escape(token) + r'\b',
              caseSensitive: false,
            ),
          )
          .toList(growable: false);

  /// Verifica se qualquer label de câmera reportado pelo SO corresponde
  /// a um software de câmera virtual ou emulador de vídeo (com word-boundary
  /// para evitar falso positivo em nomes legítimos de sensores como `jacobson`).
  static ({bool isVirtual, String? matchedLabel}) detectVirtualCameraLabels(
    List<String> cameraLabels,
  ) {
    for (final rawLabel in cameraLabels) {
      final normalized = rawLabel
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[_-]+'), ' ');
      if (normalized.isEmpty) continue;
      for (final pattern in _bannedVirtualCameraPatterns) {
        if (pattern.hasMatch(normalized)) {
          return (isVirtual: true, matchedLabel: rawLabel.trim());
        }
      }
    }
    return (isVirtual: false, matchedLabel: null);
  }

  /// Avalia os metadados de integridade do dispositivo com fallback elegante
  /// `homologation_or_pwa_limited` quando executado em Web/PWA ou homologação.
  static DeviceIntegrityMetadata evaluateDeviceIntegrity({
    List<String> cameraLabels = const <String>[],
    DeviceIntegrityVerdict? nativeVerdictOverride,
    String? nativeTokenOverride,
    String providerLabel = 'homologation_or_pwa_limited',
  }) {
    final virtualCheck = detectVirtualCameraLabels(cameraLabels);
    if (virtualCheck.isVirtual) {
      return DeviceIntegrityMetadata(
        verdict: DeviceIntegrityVerdict.virtualCameraBlocked,
        attestationProvider: providerLabel,
        attestationToken: nativeTokenOverride,
        detectedCameraLabels: List<String>.unmodifiable(cameraLabels),
        hasSuspiciousVirtualCamera: true,
        suspiciousCameraReason:
            'ERR_VIRTUAL_CAMERA_DETECTED: Câmera virtual bloqueada (${virtualCheck.matchedLabel}).',
      );
    }

    final resolvedVerdict =
        nativeVerdictOverride ?? DeviceIntegrityVerdict.homologationOrPwaLimited;
    final resolvedProvider = switch (resolvedVerdict) {
      DeviceIntegrityVerdict.meetsStrongIntegrity => 'google_play_integrity',
      DeviceIntegrityVerdict.appAttestHardware => 'apple_app_attest',
      DeviceIntegrityVerdict.homologationOrPwaLimited =>
        'homologation_or_pwa_limited',
      DeviceIntegrityVerdict.virtualCameraBlocked => providerLabel,
      DeviceIntegrityVerdict.untrustedDevice => providerLabel,
    };

    return DeviceIntegrityMetadata(
      verdict: resolvedVerdict,
      attestationProvider: resolvedProvider,
      attestationToken: nativeTokenOverride,
      detectedCameraLabels: List<String>.unmodifiable(cameraLabels),
      hasSuspiciousVirtualCamera: false,
    );
  }

  /// Valida que a captura provém exclusivamente da câmera física ao vivo.
  static void enforceLiveCameraCapture(CaptureOrigin origin) {
    if (origin != CaptureOrigin.liveCameraOnly) {
      throw StateError(
        'ERR_GALLERY_UPLOAD_BLOCKED: O envio de imagens da galeria ou arquivos '
        'estáticos é bloqueado no fluxo forense de verificação de identidade.',
      );
    }
  }

  /// Emite um novo ticket de sessão Anti-Swap com `sessionNonce` de alta entropia
  /// e validade máxima estrita de `180s`.
  static KycSessionBindingTicket issueSession({
    required String userId,
    String? serverSessionNonce,
    DateTime? nowUtc,
    int ttlSeconds = maxSessionTtlSeconds,
    List<String> detectedCameraLabels = const <String>[],
    DeviceIntegrityVerdict? nativeIntegrityOverride,
    String? nativeTokenOverride,
  }) {
    final normalizedUser = userId.trim().isEmpty ? 'anonymous_kyc_user' : userId.trim();
    final issuedAt = (nowUtc ?? DateTime.now()).toUtc();
    final effectiveTtl = ttlSeconds.clamp(30, maxSessionTtlSeconds);
    final nonce = (serverSessionNonce != null &&
            serverSessionNonce.trim().length >= 16)
        ? serverSessionNonce.trim()
        : _generateCryptographicNonce(normalizedUser, issuedAt);

    final integrity = evaluateDeviceIntegrity(
      cameraLabels: detectedCameraLabels,
      nativeVerdictOverride: nativeIntegrityOverride,
      nativeTokenOverride: nativeTokenOverride,
    );
    if (!integrity.isAllowedForKyc) {
      throw StateError(
        integrity.suspiciousCameraReason ??
            'ERR_DEVICE_INTEGRITY_FAILED: Ambiente de captura não autorizado.',
      );
    }

    return KycSessionBindingTicket(
      userId: normalizedUser,
      sessionNonce: nonce,
      issuedAtUtc: issuedAt,
      ttlSeconds: effectiveTtl,
      deviceIntegrity: integrity,
    );
  }

  /// Renova de forma elegante uma sessão expirada preservando o `userId` e
  /// metadados de integridade quando aplicável.
  static KycSessionBindingTicket renewIfExpired(
    KycSessionBindingTicket ticket, {
    DateTime? nowUtc,
    String? newServerSessionNonce,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    if (!ticket.isExpired(nowUtc: now)) {
      return ticket;
    }
    return issueSession(
      userId: ticket.userId,
      serverSessionNonce: newServerSessionNonce,
      nowUtc: now,
      ttlSeconds: ticket.ttlSeconds,
      detectedCameraLabels: ticket.deviceIntegrity.detectedCameraLabels,
      nativeIntegrityOverride: ticket.deviceIntegrity.verdict ==
              DeviceIntegrityVerdict.virtualCameraBlocked
          ? DeviceIntegrityVerdict.virtualCameraBlocked
          : ticket.deviceIntegrity.verdict,
      nativeTokenOverride: ticket.deviceIntegrity.attestationToken,
    );
  }

  /// Congela a Selfie Canônica (`selfieSha256` + `selfieDHash64`) imediatamente
  /// após a aprovação da Prova de Vida Ao Vivo.
  static KycSessionBindingTicket freezeCanonicalSelfie({
    required KycSessionBindingTicket ticket,
    required Uint8List selfieBytes,
    CaptureOrigin origin = CaptureOrigin.liveCameraOnly,
    List<String> detectedCameraLabels = const <String>[],
    DateTime? nowUtc,
  }) {
    enforceLiveCameraCapture(origin);

    if (selfieBytes.isEmpty) {
      throw StateError(
        'ERR_EMPTY_CANONICAL_SELFIE: Frame da selfie canônica está vazio.',
      );
    }

    final mergedLabels = <String>{
      ...ticket.deviceIntegrity.detectedCameraLabels,
      ...detectedCameraLabels,
    }.toList(growable: false);
    final integrity = evaluateDeviceIntegrity(
      cameraLabels: mergedLabels,
      nativeVerdictOverride: ticket.deviceIntegrity.verdict,
      nativeTokenOverride: ticket.deviceIntegrity.attestationToken,
    );
    if (!integrity.isAllowedForKyc) {
      throw StateError(
        integrity.suspiciousCameraReason ??
            'ERR_VIRTUAL_CAMERA_DETECTED: Câmera virtual bloqueada na prova de vida.',
      );
    }

    final capturedAt = (nowUtc ?? DateTime.now()).toUtc();
    final elapsedSinceIssue =
        capturedAt.difference(ticket.issuedAtUtc).inSeconds;
    final maxAllowedLivenessWindow =
        math.min(maxLivenessWindowSeconds, ticket.ttlSeconds);
    if (elapsedSinceIssue < 0 || elapsedSinceIssue > maxAllowedLivenessWindow) {
      throw StateError(
        'ERR_SESSION_EXPIRED_OR_SWAP: A sessão de verificação expirou '
        '(${elapsedSinceIssue}s > ${maxAllowedLivenessWindow}s). Inicie uma nova captura.',
      );
    }

    final selfieSha256 = sha256.convert(selfieBytes).toString();
    final selfieDHash64 = PerceptualHashGuard.computeDHash64(selfieBytes);

    final frozen = FrozenCanonicalSelfie(
      selfieSha256: selfieSha256,
      selfieDHash64: selfieDHash64,
      selfieDHashHex: PerceptualHashGuard.toHex64(selfieDHash64),
      capturedAtUtc: capturedAt,
      origin: origin,
    );

    return ticket.copyWith(
      frozenSelfie: frozen,
      deviceIntegrity: integrity,
    );
  }

  /// Calcula deterministicamente o `requestHash` canônico:
  /// `SHA256("$userId|$sessionNonce|$selfieHash|$frontDocHash|$backDocHash|$capturedAtEpochSec")`
  static String computeDeterministicRequestHash({
    required String userId,
    required String sessionNonce,
    required String selfieHash,
    required String frontDocHash,
    required String backDocHash,
    required int capturedAtEpochSec,
  }) {
    final canonicalPayload =
        '${userId.trim()}|${sessionNonce.trim()}|${selfieHash.trim().toLowerCase()}|'
        '${frontDocHash.trim().toLowerCase()}|${backDocHash.trim().toLowerCase()}|'
        '$capturedAtEpochSec';
    return sha256.convert(utf8.encode(canonicalPayload)).toString();
  }

  /// Vincula os documentos (Frente e Verso) à Selfie Canônica congelada,
  /// valida a janela temporal (`<= 180s`), bloqueia câmeras virtuais/galeria
  /// e sela o ticket com o `requestHash` SHA-256 determinístico.
  static KycSessionBindingTicket bindDocumentCapturesAndComputeRequestHash({
    required KycSessionBindingTicket ticket,
    required Uint8List frontDocBytes,
    required Uint8List backDocBytes,
    CaptureOrigin frontOrigin = CaptureOrigin.liveCameraOnly,
    CaptureOrigin backOrigin = CaptureOrigin.liveCameraOnly,
    List<String> detectedCameraLabels = const <String>[],
    DeviceIntegrityVerdict? nativeIntegrityOverride,
    DateTime? nowUtc,
  }) {
    enforceLiveCameraCapture(frontOrigin);
    enforceLiveCameraCapture(backOrigin);

    if (frontDocBytes.isEmpty || backDocBytes.isEmpty) {
      throw StateError(
        'ERR_EMPTY_DOCUMENT_BYTES: Capturas da frente e do verso são obrigatórias.',
      );
    }

    final mergedLabels = <String>{
      ...ticket.deviceIntegrity.detectedCameraLabels,
      ...detectedCameraLabels,
    }.toList(growable: false);
    final integrity = evaluateDeviceIntegrity(
      cameraLabels: mergedLabels,
      nativeVerdictOverride:
          nativeIntegrityOverride ?? ticket.deviceIntegrity.verdict,
      nativeTokenOverride: ticket.deviceIntegrity.attestationToken,
    );
    if (!integrity.isAllowedForKyc) {
      throw StateError(
        integrity.suspiciousCameraReason ??
            'ERR_VIRTUAL_CAMERA_DETECTED: Câmera virtual detectada na captura do documento.',
      );
    }

    final frozenSelfie = ticket.frozenSelfie;
    if (frozenSelfie == null) {
      throw StateError(
        'ERR_MISSING_CANONICAL_SELFIE: A prova de vida deve ser concluída antes do vínculo dos documentos.',
      );
    }

    final capturedAt = (nowUtc ?? DateTime.now()).toUtc();
    final elapsedFromSessionStart =
        capturedAt.difference(ticket.issuedAtUtc).inSeconds;
    final elapsedFromLiveness =
        capturedAt.difference(frozenSelfie.capturedAtUtc).inSeconds;

    if (elapsedFromSessionStart < 0 ||
        elapsedFromSessionStart > ticket.ttlSeconds ||
        elapsedFromLiveness < 0 ||
        elapsedFromLiveness > ticket.ttlSeconds) {
      throw StateError(
        'ERR_SESSION_EXPIRED_OR_SWAP: Tempo máximo de 180s entre a prova de vida '
        'e a captura do documento foi excedido (${math.max(elapsedFromSessionStart, elapsedFromLiveness)}s).',
      );
    }

    final frontSha256 = sha256.convert(frontDocBytes).toString();
    final backSha256 = sha256.convert(backDocBytes).toString();
    if (frontSha256 == backSha256) {
      throw StateError(
        'ERR_DUPLICATE_FRONT_BACK_PHOTO: A foto do VERSO é idêntica à foto da FRENTE.',
      );
    }

    final frontDHash64 = PerceptualHashGuard.computeDHash64(frontDocBytes);
    final backDHash64 = PerceptualHashGuard.computeDHash64(backDocBytes);
    final capturedAtEpochSec = capturedAt.millisecondsSinceEpoch ~/ 1000;

    final requestHash = computeDeterministicRequestHash(
      userId: ticket.userId,
      sessionNonce: ticket.sessionNonce,
      selfieHash: frozenSelfie.selfieSha256,
      frontDocHash: frontSha256,
      backDocHash: backSha256,
      capturedAtEpochSec: capturedAtEpochSec,
    );

    return ticket.copyWith(
      frontDocSha256: frontSha256,
      backDocSha256: backSha256,
      frontDocDHash64: frontDHash64,
      backDocDHash64: backDHash64,
      docCapturedAtUtc: capturedAt,
      requestHash: requestHash,
      deviceIntegrity: integrity,
    );
  }

  /// Verifica se um ticket selado permanece íntegro e dentro da janela de `180s`
  /// e se a selfie apresentada coincide exatamente com a Selfie Canônica congelada.
  static void verifyBoundTicketIntegrity({
    required KycSessionBindingTicket ticket,
    Uint8List? presentedSelfieBytes,
    DateTime? nowUtc,
  }) {
    if (!ticket.deviceIntegrity.isAllowedForKyc) {
      throw StateError(
        ticket.deviceIntegrity.suspiciousCameraReason ??
            'ERR_VIRTUAL_CAMERA_DETECTED: Dispositivo ou câmera não confiável.',
      );
    }

    if (ticket.isExpired(nowUtc: nowUtc)) {
      throw StateError(
        'ERR_SESSION_EXPIRED_OR_SWAP: Sessão KYC expirada ou fora da janela de 180s.',
      );
    }

    final frozen = ticket.frozenSelfie;
    if (frozen == null ||
        ticket.frontDocSha256 == null ||
        ticket.backDocSha256 == null ||
        ticket.docCapturedAtEpochSec == null ||
        ticket.requestHash == null) {
      throw StateError(
        'ERR_INCOMPLETE_SESSION_BINDING: Ticket de sessão KYC incompleto.',
      );
    }

    if (presentedSelfieBytes != null) {
      final presentedSha256 = sha256.convert(presentedSelfieBytes).toString();
      final presentedDHash =
          PerceptualHashGuard.computeDHash64(presentedSelfieBytes);
      final dHashDist = PerceptualHashGuard.hammingDistance64(
        frozen.selfieDHash64,
        presentedDHash,
      );
      if (presentedSha256 != frozen.selfieSha256 || dHashDist > 4) {
        throw StateError(
          'ERR_CANONICAL_SELFIE_SWAP_DETECTED: Tentativa de troca da selfie canônica detectada.',
        );
      }
    }

    final expectedHash = computeDeterministicRequestHash(
      userId: ticket.userId,
      sessionNonce: ticket.sessionNonce,
      selfieHash: frozen.selfieSha256,
      frontDocHash: ticket.frontDocSha256!,
      backDocHash: ticket.backDocSha256!,
      capturedAtEpochSec: ticket.docCapturedAtEpochSec!,
    );

    if (expectedHash != ticket.requestHash) {
      throw StateError(
        'ERR_REQUEST_HASH_MISMATCH: Assinatura de integridade da sessão inválida.',
      );
    }
  }

  static String _generateCryptographicNonce(
    String userId,
    DateTime issuedAtUtc,
  ) {
    final rng = math.Random.secure();
    final entropyBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final seed =
        '$userId|${issuedAtUtc.microsecondsSinceEpoch}|${base64UrlEncode(entropyBytes)}';
    return sha256.convert(utf8.encode(seed)).toString().substring(0, 32);
  }
}
