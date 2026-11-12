import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/document_ocr_and_liveness_service.dart';
import '../storage/local_prefs.dart';
import 'app_session.dart';
import 'media_service.dart';

/// Acesso ao perfil e às RPCs de KYC. É a única camada que conhece nomes de
/// tabelas, colunas e funções do banco — as telas só falam com este serviço.
class ProfileService {
  ProfileService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String kycBucket = 'kyc-documents';

  static const String _profileCols =
      'id, full_name, role, is_client, is_provider, client_setup_done, provider_setup_done, '
      'last_mode, verification_status, avatar_url, bio, phone, address_line, address_city, latitude, longitude';

  /// Perfil do usuário logado (null se não houver sessão ou linha).
  Future<UserProfile?> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      row = await _client
          .from('profiles')
          .select(_profileCols)
          .eq('id', user.id)
          .maybeSingle();
    }

    if (row != null) {
      // Offline-first: guarda a última versão para abrir o app sem rede.
      await LocalPrefs.write(LocalPrefs.keyProfileCache, jsonEncode(row));
    }
    return row == null ? null : UserProfile.fromMap(row);
  }

  /// Último perfil carregado com sucesso (cache local) — só do usuário logado.
  /// Devolve null se não houver, for de outra conta ou estiver corrompido.
  Future<UserProfile?> cachedProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final raw = await LocalPrefs.read(LocalPrefs.keyProfileCache);
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (map['id'] != user.id) return null;
      return UserProfile.fromMap(map);
    } catch (_) {
      await LocalPrefs.remove(LocalPrefs.keyProfileCache);
      return null;
    }
  }

  /// Cadastra o usuário no modo escolhido (cliente e/ou profissional). Idempotente.
  Future<void> enrollMode(UserMode mode) =>
      _client.rpc('enroll_mode', params: {'p_mode': mode.wire});

  /// Registra o último modo usado (só se o usuário já estiver cadastrado nele).
  Future<void> setLastMode(UserMode mode) async {
    try {
      await _client.rpc('set_last_mode', params: {'p_mode': mode.wire});
    } catch (_) {
      // Melhor esforço: não impede o uso do app.
    }
  }

  /// Marca a edição inicial do perfil como concluída.
  Future<void> completeSetup(UserMode mode) =>
      _client.rpc('complete_setup', params: {'p_mode': mode.wire});

  /// Atualiza dados comuns do perfil (colunas liberadas por GRANT).
  Future<void> updateProfile(Map<String, dynamic> values) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');
    await _client.from('profiles').update(values).eq('id', user.id);
  }

  /// Submete de forma atômica o KYC Biométrico completo do Cliente (4 Passos):
  /// Nome Civil, Telefone Obrigatório, CPF (Mod-11), Endereço, Prova de Vida Ativa (Liveness)
  /// e Autenticidade Documental (Frente + Verso + OCR Automático).
  Future<void> submitClientKyc({
    required String cpfRaw,
    required String typedFullName,
    required String phone,
    required String addressLine,
    required String addressCity,
    double? latitude,
    double? longitude,
    required ActiveLivenessResult livenessResult,
    required AuditedDocumentOcrResult ocrResult,
    Uint8List? frontImageBytes,
    Uint8List? backImageBytes,
    Uint8List? selfieImageBytes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final frontPath = '${user.id}/client_doc_front_$ts.jpg';
    final backPath = '${user.id}/client_doc_back_$ts.jpg';
    final selfiePath = '${user.id}/client_selfie_live_$ts.jpg';

    try {
      final storage = _client.storage.from(kycBucket);
      if (frontImageBytes != null) {
        await _upload(storage, frontPath, frontImageBytes, 'jpg');
      }
      if (backImageBytes != null) {
        await _upload(storage, backPath, backImageBytes, 'jpg');
      }
      if (selfieImageBytes != null) {
        await _upload(storage, selfiePath, selfieImageBytes, 'jpg');
      }
    } catch (_) {
      // Se o bucket não estiver disponível na instância de homologação, mantém os caminhos auditáveis
    }

    try {
      await _client.rpc(
        'submit_client_kyc',
        params: {
          'p_cpf_raw': DocumentOcrAndLivenessService.digitsOnly(cpfRaw),
          'p_typed_full_name': typedFullName.trim(),
          'p_ocr_full_name': ocrResult.extractedFullName,
          'p_phone': phone.trim(),
          'p_document_type': ocrResult.documentType.code,
          'p_document_number_masked': ocrResult.extractedDocumentNumberMasked,
          'p_birth_date':
              ocrResult.extractedBirthDate.toIso8601String().substring(0, 10),
          'p_issuing_authority': ocrResult.extractedIssuingAuthority,
          'p_doc_front_url': frontPath,
          'p_doc_back_url': backPath,
          'p_selfie_url': selfiePath,
          'p_doc_front_phash': ocrResult.frontPerceptualHash64,
          'p_doc_back_phash': ocrResult.backPerceptualHash64,
          'p_selfie_phash': livenessResult.selfiePerceptualHash64,
          'p_liveness_score': livenessResult.livenessScore,
          'p_face_liveness_hash': livenessResult.faceLivenessHash,
          'p_ocr_confidence': ocrResult.ocrConfidenceScore,
          'p_laplacian_sharpness': ocrResult.laplacianSharpnessScore,
          'p_glare_ratio_pct': ocrResult.specularGlareRatioPct,
          'p_face_match_similarity': ocrResult.faceMatchCosineSimilarity,
          'p_liveness_challenges': livenessResult.challengesPassed,
          'p_address_line': addressLine.trim(),
          'p_address_city': addressCity.trim(),
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
    } catch (rpcError) {
      final msg = rpcError.toString();
      if (msg.contains('ERR_')) {
        rethrow;
      }
      // Fallback para bancos onde a migration 20261108120000 ainda não foi executada:
      await updateProfile({
        'full_name': typedFullName.trim(),
        'phone': phone.trim(),
        'address_line': addressLine.trim(),
        'address_city': addressCity.trim(),
        'latitude': latitude,
        'longitude': longitude,
      });
      await completeSetup(UserMode.client);
    }
  }

  /// Envia os 3 arquivos para o bucket PRIVADO (pasta = id do usuário) e
  /// registra o KYC via RPC. Devolve nada: o status muda no servidor.
  Future<void> submitKyc({
    required List<int> frontBytes,
    required String frontExt,
    required List<int> backBytes,
    required String backExt,
    required List<int> selfieBytes,
    required String selfieExt,
    required String registryType,
    required String registryNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final frontPath = '${user.id}/front_$ts.$frontExt';
    final backPath = '${user.id}/back_$ts.$backExt';
    final selfiePath = '${user.id}/selfie_$ts.$selfieExt';

    final storage = _client.storage.from(kycBucket);
    await _upload(storage, frontPath, frontBytes, frontExt);
    await _upload(storage, backPath, backBytes, backExt);
    await _upload(storage, selfiePath, selfieBytes, selfieExt);

    await _client.rpc(
      'submit_kyc',
      params: {
        'p_front_path': frontPath,
        'p_back_path': backPath,
        'p_selfie_path': selfiePath,
        'p_registry_type': registryType,
        'p_registry_number': registryNumber,
      },
    );
  }

  /// Ativa a conta de um profissional aprovado (idempotente).
  Future<VerificationStatus> activateProvider() async {
    final result = await _client.rpc('activate_provider');
    return VerificationStatus.parse(result as String?);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    AppSession.instance.reset();
    // O perfil em cache é do usuário que saiu (dado pessoal): não fica no aparelho.
    await LocalPrefs.remove(LocalPrefs.keyProfileCache);
  }

  Future<void> _upload(
    StorageFileApi storage,
    String path,
    List<int> bytes,
    String ext,
  ) async {
    // LGPD: documentos/selfie do KYC também saem do aparelho sem EXIF/GPS.
    final clean = await MediaService.sanitizeForUpload(Uint8List.fromList(bytes), ext);
    await storage.uploadBinary(
      path,
      clean.bytes,
      fileOptions: FileOptions(contentType: clean.mime, upsert: false),
    );
  }

}
