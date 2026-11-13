import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/fintech_warranty_models.dart' show ForensicStage;
import '../core/security/geo_privacy_policy_engine.dart';
import '../core/security/perceptual_hash_guard.dart';
import '../core/services/media_service.dart';

/// Guarda no cofre PRIVADO `forensic-evidence` (sem EXIF/GPS) e devolve uma URL assinada.
abstract class ForensicStoragePort {
  Future<String> uploadSanitized({required String path, required Uint8List bytes});
}

class SupabaseForensicStorage implements ForensicStoragePort {
  SupabaseForensicStorage([this._client]);
  final SupabaseClient? _client;
  static const String bucket = 'forensic-evidence';

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  @override
  Future<String> uploadSanitized({required String path, required Uint8List bytes}) async {
    final clean = await MediaService.sanitizeForUpload(bytes, 'jpg');
    await _db.storage.from(bucket).uploadBinary(path, clean.bytes, fileOptions: FileOptions(contentType: clean.mime, upsert: false));
    return _db.storage.from(bucket).createSignedUrl(path, MediaService.signedUrlTtlSeconds);
  }
}

/// Caminho aceito pela política do bucket: `evidence/<jobId>/<ts>_<phash>.jpg`.
String forensicEvidencePath(String jobId, int phash, {DateTime? now}) =>
    'evidence/$jobId/${(now ?? DateTime.now()).millisecondsSinceEpoch}_${phash.abs()}.jpg';

/// Registro server-side do hash da foto (RPC `register_forensic_photo`).
abstract class ForensicRegistrarPort {
  /// `true` = o servidor gravou; `false` = a função ainda não existe no servidor.
  Future<bool> register({required String jobId, required ForensicStage stage, required int phash, required String storagePath});
}

class SupabaseForensicRegistrar implements ForensicRegistrarPort {
  SupabaseForensicRegistrar([this._client]);
  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  @override
  Future<bool> register({required String jobId, required ForensicStage stage, required int phash, required String storagePath}) async {
    try {
      await _db.rpc('register_forensic_photo', params: {
        'p_job_id': jobId,
        'p_stage': stage == ForensicStage.beforeCheckIn ? 'check_in' : 'check_out',
        'p_phash': phash,
        'p_storage_path': storagePath,
      });
      return true;
    } on PostgrestException catch (e) {
      final missing = e.code == 'PGRST202' || e.code == '42883' || e.message.contains('Could not find the function');
      if (missing) return false;
      rethrow;
    }
  }
}

enum ForensicCaptureState {
  /// Foto guardada no cofre e hash gravado no servidor.
  recorded,

  /// Foto guardada no cofre, mas o servidor ainda não tem a função de registro do hash.
  storedPendingRecord,
  cancelled,

  /// Endereço ainda protegido (fora do dia do serviço): nada é capturado.
  blocked,
  tooFar,
  mockGps,
  failed,
}

class ForensicCaptureOutcome {
  const ForensicCaptureOutcome(
    this.state,
    this.message, {
    this.storagePath,
    this.signedUrl,
    this.phash,
    this.latitude,
    this.longitude,
    this.distanceM,
  });

  final ForensicCaptureState state;

  /// Mensagem humana (pt-BR).
  final String message;
  final String? storagePath;
  final String? signedUrl;
  final int? phash;
  final double? latitude;
  final double? longitude;
  final double? distanceM;

  /// A foto realmente está no cofre (pode ir para o dossiê).
  bool get stored => state == ForensicCaptureState.recorded || state == ForensicCaptureState.storedPendingRecord;
}

typedef ForensicCamera = Future<CapturedForensicPhoto> Function();

/// Foto forense REAL de check-in/check-out: câmera ao vivo, GPS no local do serviço, EXIF removido,
/// dHash calculado fora da thread de UI, upload ao cofre privado e registro no servidor.
class ForensicPhotoService {
  ForensicPhotoService({ForensicStoragePort? storage, ForensicRegistrarPort? registrar, ForensicCamera? camera, DateTime Function()? now})
      : _storage = storage ?? SupabaseForensicStorage(),
        _registrar = registrar ?? SupabaseForensicRegistrar(),
        _camera = camera ?? (() => PerceptualHashGuard.captureStrictlyFromCamera()),
        _now = now ?? DateTime.now;

  final ForensicStoragePort _storage;
  final ForensicRegistrarPort _registrar;
  final ForensicCamera _camera;
  final DateTime Function() _now;

  /// Distância máxima (m) entre a foto e o endereço exato do serviço.
  static const double maxDistanceM = 150;

  Future<ForensicCaptureOutcome> captureAndRegister({
    required String jobId,
    required ForensicStage stage,
    required ProviderLocationView? view,
  }) async {
    // Trava de privacidade: só com o endereço exato liberado pelo servidor.
    if (view == null || !view.canShowExactMap) {
      return const ForensicCaptureOutcome(
        ForensicCaptureState.blocked,
        'O registro por foto só é liberado no dia do serviço, quando o endereço é desbloqueado.',
      );
    }

    CapturedForensicPhoto photo;
    try {
      photo = await _camera();
    } catch (e) {
      final text = e.toString();
      if (text.contains('cancelada')) {
        return const ForensicCaptureOutcome(ForensicCaptureState.cancelled, 'Captura cancelada.');
      }
      if (text.contains('Fake GPS') || text.contains('simulada')) {
        return const ForensicCaptureOutcome(ForensicCaptureState.mockGps, 'Desative a localização simulada do aparelho para registrar a foto.');
      }
      return const ForensicCaptureOutcome(
        ForensicCaptureState.failed,
        'Não foi possível abrir a câmera ou obter sua localização. Libere a câmera e o GPS e tente de novo.',
      );
    }

    if (photo.isMockLocationDetected) {
      return const ForensicCaptureOutcome(ForensicCaptureState.mockGps, 'Desative a localização simulada do aparelho para registrar a foto.');
    }

    final distance = PerceptualHashGuard.computeHaversineMeters(view.lat!, view.lng!, photo.latitude, photo.longitude);
    if (distance > maxDistanceM) {
      return ForensicCaptureOutcome(
        ForensicCaptureState.tooFar,
        'Você está a ${distance.round()} m do local do serviço. Chegue a menos de ${maxDistanceM.round()} m para registrar a foto.',
        distanceM: distance,
      );
    }

    final path = forensicEvidencePath(jobId, photo.perceptualHash64, now: _now());
    String url;
    try {
      url = await _storage.uploadSanitized(path: path, bytes: photo.bytes);
    } catch (_) {
      return const ForensicCaptureOutcome(
        ForensicCaptureState.failed,
        'Não foi possível enviar a foto agora. Verifique a internet e tente de novo — nada foi salvo.',
      );
    }

    bool recorded;
    try {
      recorded = await _registrar.register(jobId: jobId, stage: stage, phash: photo.perceptualHash64, storagePath: path);
    } catch (e) {
      final t = e.toString();
      final duplicate = t.contains('DUPLICATE') || t.contains('hamming');
      return ForensicCaptureOutcome(
        ForensicCaptureState.failed,
        duplicate
            ? 'Esta foto é parecida demais com a do outro momento do serviço. Tire uma nova foto real do local.'
            : 'A foto foi enviada, mas o registro dela não foi confirmado. Tente de novo.',
        storagePath: path,
      );
    }

    return ForensicCaptureOutcome(
      recorded ? ForensicCaptureState.recorded : ForensicCaptureState.storedPendingRecord,
      recorded
          ? 'Foto registrada com segurança.'
          : 'Foto guardada com segurança. O registro oficial dela será confirmado assim que o servidor liberar.',
      storagePath: path,
      signedUrl: url,
      phash: photo.perceptualHash64,
      latitude: photo.latitude,
      longitude: photo.longitude,
      distanceM: distance,
    );
  }
}
