import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/security/perceptual_hash_guard.dart';
import '../core/services/media_service.dart';

/// Pipeline de Pré-Aquecimento de GPS e Upload Especulativo em Background (`PDF 3 Seção 4.3`).
///
/// Reduz a latência percebida de Check-out e abertura de Mediação para < 180ms ao:
/// 1. Pré-aquecer o hardware de GPS assim que o usuário entra na tela (cache válido por 30s).
/// 2. Iniciar o upload do arquivo binário para o Storage imediatamente após a captura da foto,
///    enquanto o usuário digita a descrição ou o código PIN de 4 dígitos.
class SpeculativeEvidencePipeline {
  Position? _warmedGpsPosition;
  DateTime? _warmedAt;

  /// Retorna a última coordenada pré-aquecida se tiver menos de 30 segundos.
  Position? get cachedPosition {
    if (_warmedGpsPosition != null &&
        _warmedAt != null &&
        DateTime.now().difference(_warmedAt!).inSeconds < 30) {
      return _warmedGpsPosition;
    }
    return null;
  }

  /// Passo 1: Acionado no `initState()` da tela de Check-out ou Mediação.
  Future<void> warmUpGpsOnScreenEnter() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (!pos.isMocked) {
        _warmedGpsPosition = pos;
        _warmedAt = DateTime.now();
      }
    } catch (_) {
      // Fallback silencioso para aquisição no momento da captura
    }
  }

  /// Passo 2: Captura via câmera nativa e dispara o upload em background imediatamente.
  Future<({CapturedForensicPhoto photo, Future<String> uploadFuture})>
      captureAndStartSpeculativeUpload({
    required SupabaseClient supabase,
    required String jobId,
    String bucket = 'forensic-evidence',
  }) async {
    final photo = await PerceptualHashGuard.captureStrictlyFromCamera();
    final path =
        'evidence/$jobId/${DateTime.now().millisecondsSinceEpoch}_${photo.perceptualHash64.abs()}.jpg';

    // LGPD (contrato B.3): a foto é tirada na casa do cliente; o EXIF pode trazer o GPS
    // exato. O upload sai SEMPRE higienizado (o pHash é de pixels e não muda).
    // Bucket forense é privado: devolvemos URL assinada (a pública não funcionaria).
    final Future<String> uploadFuture = MediaService.sanitizeForUpload(photo.bytes, 'jpg').then((clean) async {
      await supabase.storage.from(bucket).uploadBinary(
            path,
            clean.bytes,
            fileOptions: FileOptions(contentType: clean.mime, upsert: false),
          );
      return supabase.storage.from(bucket).createSignedUrl(path, MediaService.signedUrlTtlSeconds);
    });

    return (photo: photo, uploadFuture: uploadFuture);
  }

  /// Gera uma chave de idempotência UUID v4 criptograficamente segura para chamadas RPC financeiras.
  static String generateIdempotencyKey() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}

/// Serviço Transacional de Custódia (Escrow), Fundo de Garantia em 3 Camadas e Mediação Forense.
class WarrantyEscrowService {
  final SupabaseClient? _client;

  const WarrantyEscrowService([this._client]);

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  /// Camada 1 (`RN-CAM-01`): Retenção integral (100%) em Conta de Custódia Vinculada (Escrow)
  /// com segregação contábil entre Mão de Obra (`laborAmount`) e Materiais (`materialsAmount`).
  Future<void> lockJobEscrow({
    required String jobId,
    required double laborAmount,
    required double materialsAmount,
    required String fourDigitPinHash,
  }) async {
    if (laborAmount <= 0) {
      throw ArgumentError('O valor de mão de obra deve ser positivo.');
    }
    if (materialsAmount < 0) {
      throw ArgumentError('O valor de materiais não pode ser negativo.');
    }
    await _db.from('jobs').update({
      'labor_amount': laborAmount,
      'materials_amount': materialsAmount,
      'escrow_status': 'LOCKED_100',
      'checkout_pin_hash': fourDigitPinHash,
      'status': 'scheduled',
    }).eq('id', jobId);
  }

  /// Conclusão do serviço (`RN-AF-03`, `RN-AF-04`, `RN-AF-05`, `RN-AF-06`):
  /// Valida geofence (<= 150m), distância de Hamming `pHash` (>= 5) e código PIN de 4 dígitos
  /// ou agenda a janela de 24h de Liberação Automática (Auto-Release).
  Future<Map<String, dynamic>> completeJobWithEscrowGuard({
    required String jobId,
    required String providerId,
    required double jobLatitude,
    required double jobLongitude,
    required int? checkInPhash,
    required CapturedForensicPhoto checkOutPhoto,
    String? clientFourDigitPin,
  }) async {
    if (checkOutPhoto.isMockLocationDetected) {
      throw StateError(
        'ERR_MOCK_GPS_DETECTED: Localização simulada (Fake GPS) detectada no dispositivo.',
      );
    }

    final double distanceM = PerceptualHashGuard.computeHaversineMeters(
      jobLatitude,
      jobLongitude,
      checkOutPhoto.latitude,
      checkOutPhoto.longitude,
    );

    if (distanceM > 150.0) {
      throw StateError(
        'ERR_GEOFENCE_VIOLATION: Você está a ${distanceM.toStringAsFixed(0)}m do endereço do serviço (máximo permitido: 150m).',
      );
    }

    if (checkInPhash != null &&
        PerceptualHashGuard.isDuplicateEvidence(
          checkInPhash,
          checkOutPhoto.perceptualHash64,
        )) {
      throw StateError(
        'ERR_DUPLICATE_FORENSIC_PHOTO: A foto de conclusão (Depois) é idêntica ou muito semelhante à foto de entrada (Antes). Tire uma nova foto real do serviço concluído.',
      );
    }

    final response = await _db.rpc(
      'complete_job_and_schedule_escrow',
      params: {
        'p_job_id': jobId,
        'p_provider_id': providerId,
        'p_checkout_phash': checkOutPhoto.perceptualHash64,
        'p_checkout_gps_distance_m': distanceM,
        'p_client_pin_plain': clientFourDigitPin,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Acionamento da Garantia / Abertura de Mediação (`RN-AF-08`, `RN-AF-09`):
  /// Congela preventivamente o repasse em maturação (`Circuit Breaker`) e abre o SLA de 6h.
  Future<String> openMediationClaim({
    required String jobId,
    required String clientId,
    required String claimCategory,
    required String defectDescription,
    required String uploadedDefectPhotoUrl,
    required double jobLatitude,
    required double jobLongitude,
    required int? checkInPhash,
    required int? checkOutPhash,
    required CapturedForensicPhoto defectPhoto,
  }) async {
    if (defectPhoto.isMockLocationDetected) {
      throw StateError(
        'ERR_MOCK_GPS_DETECTED: Localização simulada (Fake GPS) não é permitida.',
      );
    }

    final double distanceM = PerceptualHashGuard.computeHaversineMeters(
      jobLatitude,
      jobLongitude,
      defectPhoto.latitude,
      defectPhoto.longitude,
    );

    if (distanceM > 150.0) {
      throw StateError(
        'ERR_DEFECT_GEOFENCE_INVALID: A foto da falha deve ser tirada no próprio imóvel do serviço (${distanceM.toStringAsFixed(0)}m > 150m).',
      );
    }

    if (checkInPhash != null &&
        PerceptualHashGuard.isDuplicateEvidence(
          checkInPhash,
          defectPhoto.perceptualHash64,
        )) {
      throw StateError(
        'ERR_RECYCLED_CHECKIN_PHOTO: A foto enviada para a garantia é idêntica à foto original de Antes.',
      );
    }

    if (checkOutPhash != null &&
        PerceptualHashGuard.isDuplicateEvidence(
          checkOutPhash,
          defectPhoto.perceptualHash64,
        )) {
      throw StateError(
        'ERR_RECYCLED_CHECKOUT_PHOTO: A foto enviada para a garantia é idêntica à foto original de Depois.',
      );
    }

    final dynamic mediationId = await _db.rpc(
      'open_warranty_mediation',
      params: {
        'p_job_id': jobId,
        'p_client_id': clientId,
        'p_claim_category': claimCategory,
        'p_defect_description': defectDescription,
        'p_defect_photo_url': uploadedDefectPhotoUrl,
        'p_defect_photo_phash': defectPhoto.perceptualHash64,
        'p_defect_gps_distance_m': distanceM,
      },
    );

    return mediationId.toString();
  }

  /// Acionamento da Camada 3 (`RN-CAM-03`, `RN-AF-01`, `RN-AF-02`, `RN-AF-11`, `RN-AF-12`):
  /// Despacho Cego em Cascata de 5 Níveis com Grafo Zero-Link, Idempotência e Clawback First.
  Future<String> triggerLayer3BlindDispatch({
    required String mediationId,
    required double reworkLaborBudget,
    String? idempotencyKey,
  }) async {
    if (reworkLaborBudget <= 0) {
      throw ArgumentError('O orçamento de retrabalho deve ser positivo.');
    }
    final dynamic reworkJobId = await _db.rpc(
      'trigger_layer3_rework',
      params: {
        'p_mediation_id': mediationId,
        'p_rework_labor_budget': reworkLaborBudget,
        'p_idempotency_key':
            idempotencyKey ?? SpeculativeEvidencePipeline.generateIdempotencyKey(),
      },
    );
    return reworkJobId.toString();
  }

  /// Escopo Adicional durante o Retrabalho (`RN-AF-10`):
  /// Valida que o Fundo de Garantia (Camada 3) cobre apenas até o limite do defeito original
  /// (`coveredByWarrantyFund <= originalLaborCap`), enquanto qualquer escopo extra solicitado
  /// pelo cliente é cobrado via Checkout Split complementar do próprio cliente.
  static ({
    double warrantyFundPortion,
    double clientExtraCheckoutPortion,
    double totalNewOrderAmount,
  }) computeAdditionalScopeSplitCheckout({
    required double originalLaborCap,
    required double reworkDefectCost,
    required double clientRequestedExtraScopeAmount,
  }) {
    if (originalLaborCap <= 0) {
      throw ArgumentError('O teto de mão de obra original deve ser positivo.');
    }
    if (reworkDefectCost < 0 || clientRequestedExtraScopeAmount < 0) {
      throw ArgumentError('Valores de retrabalho ou escopo adicional não podem ser negativos.');
    }
    if (reworkDefectCost > originalLaborCap) {
      throw StateError(
        'ERR_COVERAGE_CAP_EXCEEDED: O custo coberto pelo Fundo de Garantia (R\$ ${reworkDefectCost.toStringAsFixed(2)}) não pode exceder 100% da mão de obra original (R\$ ${originalLaborCap.toStringAsFixed(2)}).',
      );
    }
    final double warrantyPortion =
        (reworkDefectCost * 100).roundToDouble() / 100.0;
    final double extraPortion =
        (clientRequestedExtraScopeAmount * 100).roundToDouble() / 100.0;
    return (
      warrantyFundPortion: warrantyPortion,
      clientExtraCheckoutPortion: extraPortion,
      totalNewOrderAmount:
          ((warrantyPortion + extraPortion) * 100).roundToDouble() / 100.0,
    );
  }
}
