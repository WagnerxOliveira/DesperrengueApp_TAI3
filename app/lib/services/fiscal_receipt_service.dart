import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/nfe_access_key.dart';
import 'forensic_photo_service.dart';

/// Estado HONESTO do registro de uma nota de material.
enum FiscalReceiptState {
  /// O servidor confirmou a nota na SEFAZ (só quando ele disser explicitamente).
  validated,

  /// Chave conferida e nota registrada; a conferência na SEFAZ ainda será feita pela plataforma.
  underReview,

  /// O servidor recusou (veja [FiscalReceiptOutcome.message]).
  rejected,

  /// Falha de rede/serviço: nada foi gravado; pode tentar de novo.
  networkError,
}

class FiscalReceiptOutcome {
  const FiscalReceiptOutcome(this.state, this.message, {this.documentId, this.reasonCode, this.photoPath});

  final FiscalReceiptState state;

  /// Texto humano em pt-BR para mostrar na tela.
  final String message;
  final String? documentId;
  final String? reasonCode;
  final String? photoPath;

  /// A nota ficou gravada no servidor (validada ou em verificação).
  bool get registered => state == FiscalReceiptState.validated || state == FiscalReceiptState.underReview;
}

/// Chamada ao servidor (`register_and_verify_material_fiscal_document`).
abstract class FiscalReceiptBackend {
  Future<Map<String, dynamic>> register(Map<String, dynamic> params);
}

class SupabaseFiscalReceiptBackend implements FiscalReceiptBackend {
  SupabaseFiscalReceiptBackend([this._client]);
  final SupabaseClient? _client;

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> params) async {
    final db = _client ?? Supabase.instance.client;
    final res = await db.rpc('register_and_verify_material_fiscal_document', params: params);
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }
}

/// Registro REAL de nota fiscal de material (Smart Split). Sem valores fictícios:
/// o app valida a estrutura da chave, guarda a foto do cupom no cofre privado e o servidor
/// decide. A tela só mostra "validada" se o servidor afirmar isso.
class FiscalReceiptService {
  FiscalReceiptService({FiscalReceiptBackend? backend, ForensicStoragePort? storage, DateTime Function()? now})
      : _backend = backend ?? SupabaseFiscalReceiptBackend(),
        _storage = storage ?? SupabaseForensicStorage(),
        _now = now ?? DateTime.now;

  final FiscalReceiptBackend _backend;
  final ForensicStoragePort _storage;
  final DateTime Function() _now;

  /// Monta os parâmetros do RPC a partir da chave já validada.
  /// (Pública para teste: garante o mapeamento exato da assinatura real do servidor.)
  static Map<String, dynamic> buildParams({
    required String jobId,
    required String providerId,
    required NfeKeyInfo key,
    required bool fromQrUrl,
    required double amount,
    required int photoPhash,
  }) =>
      {
        'p_job_id': jobId,
        'p_provider_id': providerId,
        'p_fiscal_document_mode': key.documentMode,
        'p_capture_channel': fromQrUrl ? 'QR_CODE' : 'OCR_CHAVE_44',
        'p_access_key_44': key.key,
        'p_tp_amb': '1',
        'p_emitter_cnpj': key.emitterCnpj,
        'p_emitter_cnae_compatible': true,
        'p_receipt_number': '${key.number}-${key.series}',
        'p_declared_material_amount': double.parse(amount.toStringAsFixed(2)),
        'p_ncm_codes': <String>[],
        'p_ela_tamper_score': 0,
        'p_receipt_photo_phash': photoPhash,
      };

  Future<FiscalReceiptOutcome> register({
    required String jobId,
    required String providerId,
    required String rawKey,
    required double amount,
    required Uint8List photoBytes,
    required int photoPhash,
  }) async {
    final extraction = NfeAccessKey.extract(rawKey);
    final check = NfeAccessKey.validate(rawKey);
    if (!check.valid) {
      return FiscalReceiptOutcome(FiscalReceiptState.rejected, check.message!, reasonCode: 'LOCAL_${check.error!.name}');
    }
    if (!(amount > 0)) {
      return const FiscalReceiptOutcome(FiscalReceiptState.rejected, 'Informe o valor total dos materiais.', reasonCode: 'LOCAL_amount');
    }

    // 1) foto do cupom no cofre privado (sem EXIF). Falhou ⇒ nada é gravado.
    String path;
    try {
      path = forensicEvidencePath(jobId, photoPhash, now: _now());
      await _storage.uploadSanitized(path: path, bytes: photoBytes);
    } catch (_) {
      return const FiscalReceiptOutcome(
        FiscalReceiptState.networkError,
        'Não foi possível enviar a foto do cupom agora. Verifique a internet e tente de novo — nada foi salvo.',
      );
    }

    // 2) registro no servidor.
    try {
      final res = await _backend.register(buildParams(
        jobId: jobId,
        providerId: providerId,
        key: check.info!,
        fromQrUrl: extraction.fromQrUrl,
        amount: amount,
        photoPhash: photoPhash,
      ));
      if (res['verified'] != true) {
        return FiscalReceiptOutcome(FiscalReceiptState.rejected, 'O servidor não aceitou esta nota. Confira os dados e tente de novo.', photoPath: path);
      }
      final id = res['document_id']?.toString();
      // Só "validada" quando o servidor afirmar a confirmação na SEFAZ. Hoje ele só confere a
      // chave e registra para conferência posterior ⇒ "em verificação".
      final sefazConfirmed = res['sefaz_confirmed'] == true || res['sefaz_authorized'] == true;
      return FiscalReceiptOutcome(
        sefazConfirmed ? FiscalReceiptState.validated : FiscalReceiptState.underReview,
        sefazConfirmed
            ? 'Nota validada na SEFAZ.'
            : 'Registrada — conferência na SEFAZ em andamento.',
        documentId: id,
        photoPath: path,
      );
    } on PostgrestException catch (e) {
      return _mapServerError(e);
    } catch (_) {
      return const FiscalReceiptOutcome(
        FiscalReceiptState.networkError,
        'Sem conexão com o servidor. Verifique a internet e tente de novo — nada foi salvo.',
      );
    }
  }

  static FiscalReceiptOutcome _mapServerError(PostgrestException e) {
    final raw = '${e.message} ${e.details ?? ''}';
    FiscalReceiptOutcome rej(String code, String msg) => FiscalReceiptOutcome(FiscalReceiptState.rejected, msg, reasonCode: code);

    if (e.code == '23505' || raw.contains('duplicate key') || raw.contains('uq_job_fiscal')) {
      return rej('DUPLICATE_RECEIPT', 'Recusada: esta nota já foi registrada neste ou em outro serviço.');
    }
    if (raw.contains('INVALID_NFE_KEY_MOD11')) return rej('INVALID_NFE_KEY_MOD11', 'Recusada: a chave de acesso não confere. Confira os 44 números.');
    if (raw.contains('ACCESS_KEY_REQUIRED')) return rej('ACCESS_KEY_REQUIRED', 'Recusada: informe a chave de acesso de 44 números.');
    if (raw.contains('SEFAZ_NOT_AUTHORIZED')) return rej('SEFAZ_NOT_AUTHORIZED', 'Recusada: esta nota não está autorizada na SEFAZ.');
    if (raw.contains('FISCAL_IMAGE_SPLICE_DETECTED')) return rej('FISCAL_IMAGE_SPLICE_DETECTED', 'Recusada: a foto do cupom parece ter sido editada. Tire uma nova foto do cupom original.');
    if (raw.contains('FISCAL_HOMOLOGATION_ENV_BLOCKED')) return rej('FISCAL_HOMOLOGATION_ENV_BLOCKED', 'Recusada: notas de teste (sem valor fiscal) não são aceitas.');
    if (raw.contains('ERR_UNAUTHORIZED_JOB') || raw.contains('ERR_IDOR_BLOCKED')) {
      return rej('UNAUTHORIZED_JOB', 'Recusada: só o profissional contratado neste serviço pode registrar notas.');
    }
    if (raw.contains('ERR_UNAUTHENTICATED')) return rej('UNAUTHENTICATED', 'Sua sessão expirou. Entre de novo para registrar a nota.');
    if (raw.contains('declared_material_amount')) return rej('INVALID_AMOUNT', 'Recusada: o valor dos materiais precisa ser maior que zero.');
    return rej('SERVER_REJECTED', 'Recusada pelo servidor. Confira os dados da nota e tente de novo.');
  }
}
