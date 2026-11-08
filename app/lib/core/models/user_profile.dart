/// Modelos puros (sem dependência de Flutter/Supabase) do perfil do usuário e
/// da regra de roteamento pós-login. Mantidos isolados para serem testáveis.
library;

import 'dart:math' as math;

/// Espelha o enum `public.verification_status` do banco.
enum VerificationStatus {
  notSubmitted('NOT_SUBMITTED'),
  pending('PENDING'),
  approvedPendingEmail('APPROVED_PENDING_EMAIL'),
  active('ACTIVE'),
  rejected('REJECTED');

  const VerificationStatus(this.wire);

  /// Valor exato armazenado no banco.
  final String wire;

  static VerificationStatus parse(String? value) => VerificationStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => notSubmitted);
}

/// Modo de uso. O mesmo usuário pode ser cliente E profissional.
enum UserMode {
  client('client'),
  provider('provider');

  const UserMode(this.wire);
  final String wire;

  static UserMode? parse(String? v) {
    for (final m in UserMode.values) {
      if (m.wire == v) return m;
    }
    return null;
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.isAdmin = false,
    this.isClient = false,
    this.isProvider = false,
    this.clientSetupDone = false,
    this.providerSetupDone = false,
    this.lastMode,
    this.verificationStatus = VerificationStatus.notSubmitted,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.addressLine,
    this.addressCity,
    this.latitude,
    this.longitude,
    // Extensões Forenses: KYC Biométrico, Liveness, OCR, Marco Zero e Carteira Bipartida (PDF 1..4)
    this.cpfMasked,
    this.cpfHash,
    this.verifiedFullName,
    this.documentType,
    this.documentNumberMasked,
    this.birthDate,
    this.issuingAuthority,
    this.clientKycStatus = 'NOT_STARTED',
    this.livenessVerified = false,
    this.livenessScore = 0.0,
    this.faceLivenessHash,
    this.ocrVerified = false,
    this.kycOcrConfidence = 0.0,
    this.kycVerifiedAt,
    this.trustTier = 'STANDARD',
    this.isTrustedAnchor = false,
    this.externalTrustScore = 0.0,
    this.kycBiometricVerified = false,
    this.meiCnpjActiveMonths = 0,
    this.technicalCertVerified = false,
    this.completedJobsCount = 0,
    this.abandonedWarrantyCount = 0,
    this.waterfallTierRank = 5,
    this.hasOpenDispute = false,
    this.clawbackDebtBalance = 0.0,
    this.availableWalletBalance = 0.0,
    this.maturingWalletBalance = 0.0,
    this.pixKeyCpfMatched = false,
  });

  final String id;
  final String fullName;
  final bool isAdmin;
  final bool isClient;
  final bool isProvider;
  final bool clientSetupDone;
  final bool providerSetupDone;
  final UserMode? lastMode;
  final VerificationStatus verificationStatus;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final String? addressLine;
  final String? addressCity;
  final double? latitude;
  final double? longitude;

  // Campos de Identidade Civil Verificada (Active Liveness + Document OCR)
  final String? cpfMasked;
  final String? cpfHash;
  final String? verifiedFullName;
  final String? documentType;
  final String? documentNumberMasked;
  final DateTime? birthDate;
  final String? issuingAuthority;
  final String clientKycStatus;
  final bool livenessVerified;
  final double livenessScore;
  final String? faceLivenessHash;
  final bool ocrVerified;
  final double kycOcrConfidence;
  final DateTime? kycVerifiedAt;

  // Campos de Governança de Garantia, Marco Zero (Cold-Start) e Carteira Bipartida
  final String trustTier;
  final bool isTrustedAnchor;
  final double externalTrustScore;
  final bool kycBiometricVerified;
  final int meiCnpjActiveMonths;
  final bool technicalCertVerified;
  final int completedJobsCount;
  final int abandonedWarrantyCount;
  final int waterfallTierRank;
  final bool hasOpenDispute;
  final double clawbackDebtBalance;
  final double availableWalletBalance;
  final double maturingWalletBalance;
  final bool pixKeyCpfMatched;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?)?.trim().isNotEmpty == true
            ? (map['full_name'] as String).trim()
            : 'Usuário',
        isAdmin: map['role'] == 'admin',
        isClient: map['is_client'] == true,
        isProvider: map['is_provider'] == true,
        clientSetupDone: map['client_setup_done'] == true,
        providerSetupDone: map['provider_setup_done'] == true,
        lastMode: UserMode.parse(map['last_mode'] as String?),
        verificationStatus:
            VerificationStatus.parse(map['verification_status'] as String?),
        avatarUrl: map['avatar_url'] as String?,
        bio: map['bio'] as String?,
        phone: map['phone'] as String?,
        addressLine: map['address_line'] as String?,
        addressCity: map['address_city'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        cpfMasked: map['cpf_masked'] as String?,
        cpfHash: map['cpf_hash'] as String?,
        verifiedFullName: map['verified_full_name'] as String?,
        documentType: map['document_type'] as String?,
        documentNumberMasked: map['document_number_masked'] as String?,
        birthDate: map['birth_date'] != null
            ? DateTime.tryParse(map['birth_date'].toString())
            : null,
        issuingAuthority: map['issuing_authority'] as String?,
        clientKycStatus: (map['client_kyc_status'] as String?) ?? 'NOT_STARTED',
        livenessVerified: (map['liveness_verified'] as bool?) ?? false,
        livenessScore: (map['liveness_score'] as num?)?.toDouble() ?? 0.0,
        faceLivenessHash: map['face_liveness_hash'] as String?,
        ocrVerified: (map['ocr_verified'] as bool?) ?? false,
        kycOcrConfidence:
            (map['kyc_ocr_confidence'] as num?)?.toDouble() ?? 0.0,
        kycVerifiedAt: map['kyc_verified_at'] != null
            ? DateTime.tryParse(map['kyc_verified_at'].toString())
            : null,
        trustTier: (map['trust_tier'] as String?) ?? 'STANDARD',
        isTrustedAnchor: (map['is_trusted_anchor'] as bool?) ?? false,
        externalTrustScore:
            (map['external_trust_score'] as num?)?.toDouble() ?? 0.0,
        kycBiometricVerified: (map['kyc_biometric_verified'] as bool?) ?? false,
        meiCnpjActiveMonths:
            (map['mei_cnpj_active_months'] as num?)?.toInt() ?? 0,
        technicalCertVerified:
            (map['technical_cert_verified'] as bool?) ?? false,
        completedJobsCount: (map['completed_jobs_count'] as num?)?.toInt() ?? 0,
        abandonedWarrantyCount:
            (map['abandoned_warranty_count'] as num?)?.toInt() ?? 0,
        waterfallTierRank: (map['waterfall_tier_rank'] as num?)?.toInt() ?? 5,
        hasOpenDispute: (map['has_open_dispute'] as bool?) ?? false,
        clawbackDebtBalance:
            (map['clawback_debt_balance'] as num?)?.toDouble() ?? 0.0,
        availableWalletBalance:
            (map['available_wallet_balance'] as num?)?.toDouble() ?? 0.0,
        maturingWalletBalance:
            (map['maturing_wallet_balance'] as num?)?.toDouble() ?? 0.0,
        pixKeyCpfMatched: (map['pix_key_cpf_matched'] as bool?) ?? false,
      );

  /// Primeiro nome para saudações. Se `full_name` for um e-mail (cadastro rápido), nunca o exibe:
  /// cai em "você" ("Olá, você!").
  String get firstName {
    final n = fullName.trim();
    if (n.isEmpty || n.contains('@')) return 'você';
    return n.split(' ').first;
  }

  bool get hasBothModes => isClient && isProvider;

  /// Identidade Civil Homologada (compartilhada entre os modos Cliente e Profissional).
  /// Quando o usuário conclui o KYC Biométrico + OCR como Cliente, sua identidade civil
  /// já fica validada para o Modo Profissional, concedendo +30 pts (`P_KYC`) no Score RTS.
  bool get hasVerifiedCivilIdentity =>
      (livenessVerified && ocrVerified) ||
      kycBiometricVerified ||
      clientKycStatus == 'APPROVED';

  /// Nome civil homologado pelo OCR (ou `fullName` caso ainda não homologado).
  String get officialCivilName =>
      (verifiedFullName != null && verifiedFullName!.trim().isNotEmpty)
          ? verifiedFullName!.trim()
          : fullName;

  /// Cálculo determinístico $O(1)$ do Score de Confiança Relativo (`RN-MZ-02`):
  /// $RTS = \text{clamp}(P_{KYC} + P_{MEI} + P_{CERT} + P_{HIST} - P_{PEN}, 0, 100)$.
  double get computedRtsScore {
    if (externalTrustScore > 0) return externalTrustScore;
    double score = 0.0;
    if (hasVerifiedCivilIdentity) score += 30.0;
    if (meiCnpjActiveMonths >= 6) score += 20.0;
    if (technicalCertVerified) score += 20.0;
    score += math.min(completedJobsCount * 6.0, 30.0);
    score -= abandonedWarrantyCount * 50.0;
    return score.clamp(0.0, 100.0);
  }

  /// Selo de Confiança do Marco Zero (`RN-MZ-01` e `RN-MZ-02`).
  String? get marcoZeroBadgeLabel {
    if (isTrustedAnchor) {
      return 'Especialista Fundador Verificado';
    }
    if (completedJobsCount == 0 && computedRtsScore >= 70.0) {
      return 'Novo na Plataforma • Credencial e MEI Verificados';
    }
    return null;
  }

  /// Em que ponto do cadastro o usuário está em cada modo.
  ModeStage stageOf(UserMode mode) {
    switch (mode) {
      case UserMode.client:
        if (!isClient) return ModeStage.notEnrolled;
        return (clientSetupDone && clientKycStatus != 'REJECTED')
            ? ModeStage.ready
            : ModeStage.incomplete;
      case UserMode.provider:
        if (!isProvider) return ModeStage.notEnrolled;
        switch (verificationStatus) {
          case VerificationStatus.notSubmitted:
          case VerificationStatus.rejected:
            return ModeStage.incomplete;
          case VerificationStatus.pending:
          case VerificationStatus.approvedPendingEmail:
            return ModeStage.awaitingReview;
          case VerificationStatus.active:
            return providerSetupDone ? ModeStage.ready : ModeStage.incomplete;
        }
    }
  }

  /// Modo a abrir automaticamente: só quando existe UM único modo cadastrado e
  /// o cadastro dele já foi concluído (ou está em análise). Se o usuário nunca
  /// se cadastrou, ou deixou um cadastro pela metade, ele vê a seleção para
  /// escolher/terminar ("Termine o seu cadastro").
  /// [preferred] = último perfil usado neste aparelho (cache local). Com os DOIS
  /// perfis prontos, abre direto nele (sem repetir a seleção a cada abertura);
  /// a seleção continua a um toque em "Trocar de modo".
  UserMode? autoModeWith(UserMode? preferred) {
    final auto = autoMode;
    if (auto != null || preferred == null) return auto;
    final stage = stageOf(preferred);
    return (stage == ModeStage.ready || stage == ModeStage.awaitingReview)
        ? preferred
        : null;
  }

  UserMode? get autoMode {
    final only = (isClient && !isProvider)
        ? UserMode.client
        : (isProvider && !isClient)
            ? UserMode.provider
            : null;
    if (only == null) return null;
    final stage = stageOf(only);
    return (stage == ModeStage.ready || stage == ModeStage.awaitingReview)
        ? only
        : null;
  }
}

/// Estágio do cadastro do usuário em um modo (cliente ou profissional).
enum ModeStage {
  /// Nunca escolheu este modo.
  notEnrolled,

  /// Começou mas ainda falta concluir ("Termine o seu cadastro").
  incomplete,

  /// Enviou tudo e aguarda a análise/aprovação (profissional).
  awaitingReview,

  /// Cadastro concluído.
  ready,
}

/// Para onde o usuário autenticado deve ir.
enum AppDestination {
  adminHome,
  modeSelection,
  clientEnroll,
  clientSetup,
  clientHome,
  providerEnroll,
  kycStart,
  kycInReview,
  kycApproved,
  providerSetup,
  providerHome,
}

/// Regra única de roteamento pós-autenticação.
///
/// [mode] é o modo escolhido na sessão atual (null = ainda não escolheu).
/// [forceSelection] reabre a seleção mesmo com um único modo ("Trocar de modo").
///
/// [preferred] é o último perfil usado (cache local) — ver [UserProfile.autoModeWith].
AppDestination destinationFor(
  UserProfile profile, {
  UserMode? mode,
  bool forceSelection = false,
  UserMode? preferred,
}) {
  if (profile.isAdmin) return AppDestination.adminHome;

  var current = mode;
  if (current == null && !forceSelection) {
    current = profile.autoModeWith(preferred);
  }
  if (current == null) return AppDestination.modeSelection;

  switch (current) {
    case UserMode.client:
      if (!profile.isClient) return AppDestination.clientEnroll;
      if (!profile.clientSetupDone || profile.clientKycStatus == 'REJECTED') {
        return AppDestination.clientSetup;
      }
      return AppDestination.clientHome;
    case UserMode.provider:
      if (!profile.isProvider) return AppDestination.providerEnroll;
      switch (profile.verificationStatus) {
        case VerificationStatus.notSubmitted:
        case VerificationStatus.rejected:
          return AppDestination.kycStart;
        case VerificationStatus.pending:
          return AppDestination.kycInReview;
        case VerificationStatus.approvedPendingEmail:
          return AppDestination.kycApproved;
        case VerificationStatus.active:
          return profile.providerSetupDone
              ? AppDestination.providerHome
              : AppDestination.providerSetup;
      }
  }
}
