import 'dart:typed_data';

import 'package:desperrengue_app/core/models/fintech_warranty_models.dart' show ForensicStage;
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/security/perceptual_hash_guard.dart';
import 'package:desperrengue_app/core/utils/nfe_access_key.dart';
import 'package:desperrengue_app/features/shared/presentation/scheduled_service_screen.dart';
import 'package:desperrengue_app/services/fiscal_receipt_service.dart';
import 'package:desperrengue_app/services/forensic_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nfe_access_key_test.dart' show buildKey;

class _Storage implements ForensicStoragePort {
  _Storage({this.fail = false});
  final bool fail;
  final uploads = <String>[];
  @override
  Future<String> uploadSanitized({required String path, required Uint8List bytes}) async {
    if (fail) throw StateError('offline');
    uploads.add(path);
    return 'https://signed/$path';
  }
}

class _Backend implements FiscalReceiptBackend {
  _Backend({this.result, this.error});
  final Map<String, dynamic>? result;
  final Object? error;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> params) async {
    calls.add(params);
    if (error != null) throw error!;
    return result ?? {'verified': true, 'document_id': 'doc-1'};
  }
}

class _Registrar implements ForensicRegistrarPort {
  _Registrar({this.supported = true, this.error});
  final bool supported;
  final Object? error;
  final calls = <({String job, ForensicStage stage, int phash, String path})>[];
  @override
  Future<bool> register({required String jobId, required ForensicStage stage, required int phash, required String storagePath}) async {
    if (error != null) throw error!;
    if (!supported) return false;
    calls.add((job: jobId, stage: stage, phash: phash, path: storagePath));
    return true;
  }
}

const _unlocked = ProviderLocationView(
  phase: GeoPrivacyPhase.serviceDay,
  exactUnlocked: true,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Centro',
  street: 'Rua A',
  number: '10',
  lat: -21.78,
  lng: -46.56,
  radiusM: 100,
);
const _locked = ProviderLocationView(phase: GeoPrivacyPhase.confirmedFuture, exactUnlocked: false, city: 'Poços de Caldas', uf: 'MG', neighborhood: 'Centro', lat: -21.781, lng: -46.561, radiusM: 650);

CapturedForensicPhoto _photo({double lat = -21.78, double lng = -46.56, bool mock = false, int hash = 123456}) => CapturedForensicPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      perceptualHash64: hash,
      capturedAtUtc: DateTime.utc(2026, 11, 13),
      latitude: lat,
      longitude: lng,
      gpsAccuracyMeters: 5,
      isMockLocationDetected: mock,
    );

void main() {
  final key = buildKey();
  final bytes = Uint8List.fromList([9, 9, 9]);

  group('FiscalReceiptService', () {
    test('mapeia a assinatura REAL do servidor (14 parâmetros, sem constantes fictícias)', () {
      final info = NfeAccessKey.validate(key).info!;
      final p = FiscalReceiptService.buildParams(jobId: 'j', providerId: 'p', key: info, fromQrUrl: false, amount: 1250.5, photoPhash: 77);
      expect(p.keys.toSet(), {
        'p_job_id', 'p_provider_id', 'p_fiscal_document_mode', 'p_capture_channel', 'p_access_key_44', 'p_tp_amb',
        'p_emitter_cnpj', 'p_emitter_cnae_compatible', 'p_receipt_number', 'p_declared_material_amount', 'p_ncm_codes',
        'p_ela_tamper_score', 'p_receipt_photo_phash',
      });
      expect(p['p_fiscal_document_mode'], 'NFCE_65');
      expect(p['p_capture_channel'], 'OCR_CHAVE_44');
      expect(p['p_access_key_44'], key);
      expect(p['p_emitter_cnpj'], '11222333000181');
      expect(p['p_receipt_number'], '1234-1');
      expect(p['p_declared_material_amount'], 1250.5);
      expect(p['p_receipt_photo_phash'], 77);
      expect(FiscalReceiptService.buildParams(jobId: 'j', providerId: 'p', key: info, fromQrUrl: true, amount: 1, photoPhash: 1)['p_capture_channel'], 'QR_CODE');
    });

    test('servidor registra mas NÃO confirma SEFAZ ⇒ "em verificação" (nunca "validada")', () async {
      final b = _Backend(result: {'verified': true, 'document_id': 'doc-9'});
      final s = FiscalReceiptService(backend: b, storage: _Storage());
      final o = await s.register(jobId: 'j', providerId: 'p', rawKey: key, amount: 50, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.underReview);
      expect(o.registered, isTrue);
      expect(o.documentId, 'doc-9');
      expect(o.message.toLowerCase(), isNot(contains('validada')));
      expect(o.photoPath, startsWith('evidence/j/'));
      expect(b.calls, hasLength(1));
    });

    test('só vira "validada" quando o servidor afirma a confirmação na SEFAZ', () async {
      final s = FiscalReceiptService(backend: _Backend(result: {'verified': true, 'sefaz_confirmed': true}), storage: _Storage());
      final o = await s.register(jobId: 'j', providerId: 'p', rawKey: key, amount: 50, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.validated);
    });

    test('chave inválida é recusada localmente: nada é enviado', () async {
      final b = _Backend();
      final st = _Storage();
      final s = FiscalReceiptService(backend: b, storage: st);
      final o = await s.register(jobId: 'j', providerId: 'p', rawKey: '123', amount: 50, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.rejected);
      expect(b.calls, isEmpty);
      expect(st.uploads, isEmpty);
    });

    test('valor zero é recusado localmente', () async {
      final s = FiscalReceiptService(backend: _Backend(), storage: _Storage());
      final o = await s.register(jobId: 'j', providerId: 'p', rawKey: key, amount: 0, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.rejected);
    });

    test('recusas do servidor viram texto humano em pt-BR', () async {
      Future<FiscalReceiptOutcome> run(PostgrestException e) =>
          FiscalReceiptService(backend: _Backend(error: e), storage: _Storage()).register(jobId: 'j', providerId: 'p', rawKey: key, amount: 10, photoBytes: bytes, photoPhash: 5);

      var o = await run(const PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505'));
      expect(o.state, FiscalReceiptState.rejected);
      expect(o.message, contains('já foi registrada'));
      expect(o.registered, isFalse);

      o = await run(const PostgrestException(message: 'SEFAZ_NOT_AUTHORIZED: Documento fiscal não autorizado', code: 'P0001'));
      expect(o.message, contains('não está autorizada'));

      o = await run(const PostgrestException(message: 'FISCAL_IMAGE_SPLICE_DETECTED: ...', code: 'P0001'));
      expect(o.message, contains('editada'));

      o = await run(const PostgrestException(message: 'INVALID_NFE_KEY_MOD11: x', code: '22023'));
      expect(o.message, contains('não confere'));

      o = await run(const PostgrestException(message: 'algo inesperado', code: 'XX000'));
      expect(o.state, FiscalReceiptState.rejected);
      for (final x in ['SEFAZ_NOT_AUTHORIZED', 'P0001', 'Postgrest']) {
        expect(o.message, isNot(contains(x)));
      }
    });

    test('erro de rede no servidor ⇒ networkError (pode tentar de novo)', () async {
      final o = await FiscalReceiptService(backend: _Backend(error: StateError('socket')), storage: _Storage())
          .register(jobId: 'j', providerId: 'p', rawKey: key, amount: 10, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.networkError);
      expect(o.registered, isFalse);
    });

    test('falha ao enviar a foto ⇒ networkError e o servidor NÃO é chamado', () async {
      final b = _Backend();
      final o = await FiscalReceiptService(backend: b, storage: _Storage(fail: true))
          .register(jobId: 'j', providerId: 'p', rawKey: key, amount: 10, photoBytes: bytes, photoPhash: 5);
      expect(o.state, FiscalReceiptState.networkError);
      expect(b.calls, isEmpty);
    });
  });

  group('ForensicPhotoService (check-in / check-out reais)', () {
    ForensicPhotoService svc({_Storage? st, _Registrar? reg, Future<CapturedForensicPhoto> Function()? cam}) => ForensicPhotoService(
          storage: st ?? _Storage(),
          registrar: reg ?? _Registrar(),
          camera: cam ?? () async => _photo(),
          now: () => DateTime.utc(2026, 11, 13, 12),
        );

    test('caminho aceito pela política do bucket privado', () {
      expect(forensicEvidencePath('job1', -99, now: DateTime.fromMillisecondsSinceEpoch(1000)), 'evidence/job1/1000_99.jpg');
    });

    test('endereço protegido (ou fase desconhecida): não abre câmera nem envia nada', () async {
      var cameraCalls = 0;
      final st = _Storage();
      final s = svc(st: st, cam: () async {
        cameraCalls++;
        return _photo();
      });
      for (final v in [_locked, null]) {
        final o = await s.captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: v);
        expect(o.state, ForensicCaptureState.blocked);
        expect(o.stored, isFalse);
      }
      expect(cameraCalls, 0);
      expect(st.uploads, isEmpty);
    });

    test('no local: guarda no cofre, registra o hash e devolve caminho real (sem forensic://)', () async {
      final reg = _Registrar();
      final st = _Storage();
      final o = await svc(st: st, reg: reg).captureAndRegister(jobId: 'j', stage: ForensicStage.afterCheckOut, view: _unlocked);
      expect(o.state, ForensicCaptureState.recorded);
      expect(o.stored, isTrue);
      expect(o.storagePath, startsWith('evidence/j/'));
      expect(o.storagePath, isNot(contains('forensic://')));
      expect(reg.calls.single.stage, ForensicStage.afterCheckOut);
      expect(reg.calls.single.phash, 123456);
      expect(st.uploads.single, o.storagePath);
    });

    test('servidor sem a função de registro ainda: foto guardada, mensagem honesta', () async {
      final o = await svc(reg: _Registrar(supported: false)).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.storedPendingRecord);
      expect(o.stored, isTrue);
      expect(o.message, contains('será confirmado'));
    });

    test('longe do imóvel (> 150 m): recusa sem enviar', () async {
      final st = _Storage();
      final o = await svc(st: st, cam: () async => _photo(lat: -21.80, lng: -46.56)).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.tooFar);
      expect(o.distanceM! > 150, isTrue);
      expect(st.uploads, isEmpty);
    });

    test('GPS simulado, cancelamento e câmera indisponível', () async {
      var o = await svc(cam: () async => _photo(mock: true)).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.mockGps);
      o = await svc(cam: () async => throw StateError('Captura de evidência cancelada.')).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.cancelled);
      o = await svc(cam: () async => throw Exception('permission')).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.failed);
      expect(o.message, isNot(contains('Exception')));
    });

    test('falha de upload: nada é registrado', () async {
      final reg = _Registrar();
      final o = await svc(st: _Storage(fail: true), reg: reg).captureAndRegister(jobId: 'j', stage: ForensicStage.beforeCheckIn, view: _unlocked);
      expect(o.state, ForensicCaptureState.failed);
      expect(o.stored, isFalse);
      expect(reg.calls, isEmpty);
    });

    test('foto parecida demais com a do outro momento: mensagem clara', () async {
      final o = await svc(reg: _Registrar(error: const PostgrestException(message: 'DUPLICATE_PHOTO hamming', code: 'P0001'))).captureAndRegister(jobId: 'j', stage: ForensicStage.afterCheckOut, view: _unlocked);
      expect(o.state, ForensicCaptureState.failed);
      expect(o.message, contains('parecida demais'));
    });
  });

  group('Sandbox de check-in (release-aware)', () {
    test('release: desligado por padrão; debug: ligado; override explícito manda', () {
      expect(shouldShowCheckinSandbox(releaseMode: true), isFalse);
      expect(shouldShowCheckinSandbox(releaseMode: false), isTrue);
      expect(shouldShowCheckinSandbox(releaseMode: true, envOverride: true), isTrue);
      expect(shouldShowCheckinSandbox(releaseMode: false, envOverride: false), isFalse);
    });

    test('em teste (não-release, sem dart-define) a constante fica ligada', () {
      expect(kCheckinSandboxUi, isTrue);
    });
  });
}
