import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fintech_warranty_models.dart';
import '../models/marketplace_models.dart';

/// Estado imutável de um pedido no ecossistema Anti-Bypass Fintech + Garantia em 3 Camadas.
@immutable
class OrderFintechDossierState {
  const OrderFintechDossierState({
    required this.orderId,
    required this.serviceCategoryName,
    required this.serviceTitle,
    required this.clientName,
    required this.providerId,
    required this.providerName,
    required this.propertyAddress,
    required this.serviceLaborAmount,
    this.checkInBeforePhotos = const <ForensicPhotoEvidence>[],
    this.checkOutAfterPhotos = const <ForensicPhotoEvidence>[],
    this.reimbursedMaterials = const <MaterialReimbursementTicket>[],
    this.certificate,
    this.activeClaimTicket,
  });

  final String orderId;
  final String serviceCategoryName;
  final String serviceTitle;
  final String clientName;
  final String providerId;
  final String providerName;
  final String propertyAddress;
  final double serviceLaborAmount;
  final List<ForensicPhotoEvidence> checkInBeforePhotos;
  final List<ForensicPhotoEvidence> checkOutAfterPhotos;
  final List<MaterialReimbursementTicket> reimbursedMaterials;
  final WarrantyCertificate? certificate;
  final WarrantyClaimTicket? activeClaimTicket;

  /// Soma apenas dos cupons fiscais aprovados pelo cliente (Carteira B — 0% de taxa).
  double get approvedMaterialTotal => SecurityAndLgpdGuard.roundCurrency(
        reimbursedMaterials
            .where((m) => m.isApprovedByClient)
            .fold(0.0, (sum, m) => sum + m.receiptTotalAmount),
      );

  /// Soma de todos os cupons lançados (aprovados + pendentes para simulação transparente).
  double get totalDeclaredMaterialAmount => SecurityAndLgpdGuard.roundCurrency(
        reimbursedMaterials.fold(0.0, (sum, m) => sum + m.receiptTotalAmount),
      );

  /// Demonstrativo em tempo real do Split Inteligente (Carteira A + Carteira B).
  SmartSplitBreakdown get splitBreakdown => SmartSplitBreakdown.validated(
        serviceLaborAmount: serviceLaborAmount,
        materialReimbursementAmount: approvedMaterialTotal > 0
            ? approvedMaterialTotal
            : totalDeclaredMaterialAmount,
      );

  bool get hasMinimumCheckInPhotos => checkInBeforePhotos.length >= 2;
  bool get hasMinimumCheckOutPhotos => checkOutAfterPhotos.length >= 2;
  bool get isReadyToIssueCertificate =>
      hasMinimumCheckInPhotos && hasMinimumCheckOutPhotos;

  OrderFintechDossierState copyWith({
    String? orderId,
    String? serviceCategoryName,
    String? serviceTitle,
    String? clientName,
    String? providerId,
    String? providerName,
    String? propertyAddress,
    double? serviceLaborAmount,
    List<ForensicPhotoEvidence>? checkInBeforePhotos,
    List<ForensicPhotoEvidence>? checkOutAfterPhotos,
    List<MaterialReimbursementTicket>? reimbursedMaterials,
    WarrantyCertificate? certificate,
    WarrantyClaimTicket? activeClaimTicket,
  }) {
    return OrderFintechDossierState(
      orderId: orderId ?? this.orderId,
      serviceCategoryName: serviceCategoryName ?? this.serviceCategoryName,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      clientName: clientName ?? this.clientName,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      serviceLaborAmount: serviceLaborAmount ?? this.serviceLaborAmount,
      checkInBeforePhotos: checkInBeforePhotos ?? this.checkInBeforePhotos,
      checkOutAfterPhotos: checkOutAfterPhotos ?? this.checkOutAfterPhotos,
      reimbursedMaterials: reimbursedMaterials ?? this.reimbursedMaterials,
      certificate: certificate ?? this.certificate,
      activeClaimTicket: activeClaimTicket ?? this.activeClaimTicket,
    );
  }
}

/// Estado global do controlador Anti-Bypass Fintech, Livro-Razão do Fundo de Reserva (1,5%)
/// e Passaporte de Manutenção do Imóvel ("Prontuário da Casa").
@immutable
class AntiBypassFintechGlobalState {
  const AntiBypassFintechGlobalState({
    this.orders = const <String, OrderFintechDossierState>{},
    this.reserveFundBalance = 1480.00,
    this.providerClawbackLedger = const <String, double>{},
    required this.propertyPassport,
  });

  final Map<String, OrderFintechDossierState> orders;

  /// Saldo acumulado no Livro-Razão do Fundo de Reserva de Garantia (1,5% de cada Carteira A).
  final double reserveFundBalance;

  /// Registro de débito futuro (Clawback) por prestador infrator na Camada 3.
  final Map<String, double> providerClawbackLedger;

  /// Passaporte de Manutenção do Imóvel ("Prontuário da Casa") do endereço ativo.
  final PropertyMaintenancePassport propertyPassport;

  AntiBypassFintechGlobalState copyWith({
    Map<String, OrderFintechDossierState>? orders,
    double? reserveFundBalance,
    Map<String, double>? providerClawbackLedger,
    PropertyMaintenancePassport? propertyPassport,
  }) {
    return AntiBypassFintechGlobalState(
      orders: orders ?? this.orders,
      reserveFundBalance: reserveFundBalance != null
          ? SecurityAndLgpdGuard.roundCurrency(reserveFundBalance)
          : this.reserveFundBalance,
      providerClawbackLedger:
          providerClawbackLedger ?? this.providerClawbackLedger,
      propertyPassport: propertyPassport ?? this.propertyPassport,
    );
  }
}

/// Controlador Riverpod do Pilar Anti-Bypass, Split Inteligente (Carteira A + B),
/// Certificado Digital de Garantia, 3 Camadas de Garantia e Prontuário da Casa.
class AntiBypassFintechController extends Notifier<AntiBypassFintechGlobalState> {
  @override
  AntiBypassFintechGlobalState build() {
    return FintechLedgerStore.instance.state;
  }

  /// Inicializa ou recupera o dossiê fintech de um pedido específico.
  OrderFintechDossierState ensureOrder({
    required String orderId,
    String serviceCategoryName = 'Elétrica',
    String serviceTitle = 'Manutenção Residencial Certificada',
    String clientName = 'Wagner Oliveira',
    String providerId = 'prov-001',
    String providerName = 'Carlos Mendes (Credenciado)',
    String propertyAddress = 'Av. Brasil, 1450 — Centro',
    double serviceLaborAmount = 180.0,
  }) {
    final updated = FintechLedgerStore.instance.ensureOrder(
      orderId: orderId,
      serviceCategoryName: serviceCategoryName,
      serviceTitle: serviceTitle,
      clientName: clientName,
      providerId: providerId,
      providerName: providerName,
      propertyAddress: propertyAddress,
      serviceLaborAmount: serviceLaborAmount,
    );
    state = FintechLedgerStore.instance.state;
    return updated;
  }

  /// Adiciona uma foto forense de Check-in ("Antes") com GPS verificado e hash de integridade.
  OrderFintechDossierState addCheckInPhoto({
    required String orderId,
    required String imagePathOrUrl,
    required String captionOrTechnicalNote,
    double? latitude = -18.9186,
    double? longitude = -48.2772,
    bool isGpsVerifiedAtAddress = true,
  }) {
    final res = FintechLedgerStore.instance.addCheckInPhoto(
      orderId: orderId,
      imagePathOrUrl: imagePathOrUrl,
      captionOrTechnicalNote: captionOrTechnicalNote,
      latitude: latitude,
      longitude: longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress,
    );
    state = FintechLedgerStore.instance.state;
    return res;
  }

  /// Adiciona uma foto forense de Check-out ("Depois") e emite automaticamente o Certificado
  /// caso a cadeia forense (2+ Antes e 2+ Depois) esteja completa.
  OrderFintechDossierState addCheckOutPhoto({
    required String orderId,
    required String imagePathOrUrl,
    required String captionOrTechnicalNote,
    double? latitude = -18.9186,
    double? longitude = -48.2772,
    bool isGpsVerifiedAtAddress = true,
  }) {
    final res = FintechLedgerStore.instance.addCheckOutPhoto(
      orderId: orderId,
      imagePathOrUrl: imagePathOrUrl,
      captionOrTechnicalNote: captionOrTechnicalNote,
      latitude: latitude,
      longitude: longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress,
    );
    state = FintechLedgerStore.instance.state;
    return res;
  }

  /// Lança um Cupom Fiscal de Reembolso de Peças (Carteira B — 0% de taxa).
  OrderFintechDossierState addMaterialReceipt({
    required String orderId,
    required String materialDescription,
    required String storeName,
    required String fiscalReceiptNumber,
    required double receiptTotalAmount,
    bool approvedByClient = true,
  }) {
    final res = FintechLedgerStore.instance.addMaterialReceipt(
      orderId: orderId,
      materialDescription: materialDescription,
      storeName: storeName,
      fiscalReceiptNumber: fiscalReceiptNumber,
      receiptTotalAmount: receiptTotalAmount,
      approvedByClient: approvedByClient,
    );
    state = FintechLedgerStore.instance.state;
    return res;
  }

  /// Alterna a aprovação do cliente sobre um Cupom Fiscal da Carteira B.
  OrderFintechDossierState toggleMaterialReceiptApproval({
    required String orderId,
    required String ticketId,
  }) {
    final res = FintechLedgerStore.instance.toggleMaterialReceiptApproval(
      orderId: orderId,
      ticketId: ticketId,
    );
    state = FintechLedgerStore.instance.state;
    return res;
  }

  /// Emite o Certificado Digital de Garantia e registra no Passaporte do Imóvel e no Fundo de 1,5%.
  WarrantyCertificate issueCertificate(String orderId, {int warrantyDurationDays = 90}) {
    final cert = FintechLedgerStore.instance.issueCertificate(
      orderId,
      warrantyDurationDays: warrantyDurationDays,
    );
    state = FintechLedgerStore.instance.state;
    return cert;
  }

  /// Configura os metadados oficiais do Imóvel no Passaporte (Padrão ABNT NBR 5674) pelo cliente.
  PropertyMaintenancePassport configurePropertyPassport({
    required String ownerName,
    required String propertyNickname,
    required String propertyAddress,
    required String propertyType,
    required String passportPurpose,
    required List<String> inspectedSystems,
  }) {
    final updated = FintechLedgerStore.instance.configurePropertyPassport(
      ownerName: ownerName,
      propertyNickname: propertyNickname,
      propertyAddress: propertyAddress,
      propertyType: propertyType,
      passportPurpose: passportPurpose,
      inspectedSystems: inspectedSystems,
    );
    state = FintechLedgerStore.instance.state;
    return updated;
  }

  /// Registra uma manutenção real informada/homologada pelo próprio usuário cliente no Passaporte do Imóvel.
  PropertyMaintenanceEntry registerClientMaintenanceEntry({
    required String serviceCategoryName,
    required String serviceTitle,
    required String providerName,
    required double laborAmount,
    required double materialAmount,
    int warrantyDurationDays = 90,
    String? propertyAddress,
    String? ownerName,
  }) {
    final entry = FintechLedgerStore.instance.registerClientMaintenanceEntry(
      serviceCategoryName: serviceCategoryName,
      serviceTitle: serviceTitle,
      providerName: providerName,
      laborAmount: laborAmount,
      materialAmount: materialAmount,
      warrantyDurationDays: warrantyDurationDays,
      propertyAddress: propertyAddress,
      ownerName: ownerName,
    );
    state = FintechLedgerStore.instance.state;
    return entry;
  }

  /// Remove um registro manual inserido pelo cliente no Passaporte do Imóvel.
  PropertyMaintenancePassport removeClientMaintenanceEntry(String entryId) {
    final updated = FintechLedgerStore.instance.removeClientMaintenanceEntry(entryId);
    state = FintechLedgerStore.instance.state;
    return updated;
  }

  /// Sincroniza automaticamente o nome e o endereço real do perfil do cliente caso ainda não tenham sido configurados.
  PropertyMaintenancePassport syncPassportOwnerAndAddress({
    String? ownerName,
    String? propertyAddress,
  }) {
    final updated = FintechLedgerStore.instance.syncPassportOwnerAndAddress(
      ownerName: ownerName,
      propertyAddress: propertyAddress,
    );
    state = FintechLedgerStore.instance.state;
    return updated;
  }

  /// Aciona ou escala uma das 3 Camadas da Garantia Desperrengue.
  WarrantyClaimTicket triggerWarrantyLayer({
    required String orderId,
    required WarrantyResolutionLayer layer,
    required String claimReason,
    double hoursSinceCompletion = 18.0,
    double? requestedRescueAmount,
    String rescueProviderId = 'prov-socorrista-99',
  }) {
    final ticket = FintechLedgerStore.instance.triggerWarrantyLayer(
      orderId: orderId,
      layer: layer,
      claimReason: claimReason,
      hoursSinceCompletion: hoursSinceCompletion,
      requestedRescueAmount: requestedRescueAmount,
      rescueProviderId: rescueProviderId,
    );
    state = FintechLedgerStore.instance.state;
    return ticket;
  }
}

final antiBypassFintechControllerProvider =
    NotifierProvider<AntiBypassFintechController, AntiBypassFintechGlobalState>(
  AntiBypassFintechController.new,
);

/// Store reativo em memória que mantém o Livro-Razão do Fundo de Reserva (1,5%),
/// os Dossiês Forenses por pedido e o Passaporte de Manutenção do Imóvel sincronizados
/// entre todas as telas (Cliente e Prestador) e testes.
class FintechLedgerStore extends ValueNotifier<AntiBypassFintechGlobalState> {
  FintechLedgerStore._() : super(_createInitialSeedState());

  static final FintechLedgerStore instance = FintechLedgerStore._();

  AntiBypassFintechGlobalState get state => value;
  AntiBypassFintechGlobalState get _state => value;
  set _state(AntiBypassFintechGlobalState next) => value = next;

  static AntiBypassFintechGlobalState _createInitialSeedState() {
    final now = DateTime.now().toUtc();

    return AntiBypassFintechGlobalState(
      reserveFundBalance: 1480.00,
      propertyPassport: PropertyMaintenancePassport(
        passportId: 'PASS-IMOVEL-2026-BR01',
        propertyAddress: '',
        ownerName: '',
        propertyNickname: 'Residência Principal',
        propertyType: 'Casa Residencial',
        passportPurpose: 'Vistoria de Imobiliária / Entrega de Chaves',
        inspectedSystems: const <String>[],
        isConfiguredByClient: false,
        updatedAt: now,
        entries: const <PropertyMaintenanceEntry>[],
      ),
    );
  }

  /// Resolve ou inicializa o dossiê fintech para um `Job` do marketplace.
  OrderFintechDossierState resolveForJob(Job job, {String? addressOverride}) {
    final existing = _state.orders[job.id];
    if (existing != null) return existing;
    return ensureOrder(
      orderId: job.id,
      serviceCategoryName: job.category,
      serviceTitle: job.title,
      clientName: 'Wagner Oliveira',
      providerId: job.providerId ?? 'prov-credenciado',
      providerName: 'Profissional Verificado Desperrengue',
      propertyAddress: addressOverride ?? job.addressSummary ?? 'Endereço residencial verificado via GPS',
      serviceLaborAmount: (job.agreedPrice != null && job.agreedPrice! > 0) ? job.agreedPrice! : 150.0,
    );
  }

  OrderFintechDossierState ensureOrder({
    required String orderId,
    String serviceCategoryName = 'Elétrica',
    String serviceTitle = 'Manutenção Residencial Certificada',
    String clientName = 'Wagner Oliveira',
    String providerId = 'prov-001',
    String providerName = 'Carlos Mendes (Credenciado)',
    String propertyAddress = 'Av. Brasil, 1450 — Centro',
    double serviceLaborAmount = 150.0,
  }) {
    final existing = _state.orders[orderId];
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final safeLabor = SecurityAndLgpdGuard.validateAmount(
      serviceLaborAmount > 0 ? serviceLaborAmount : 150.0,
    );

    // Pré-popula com 2 fotos de Check-in verificadas e 1 Cupom Fiscal de exemplo
    // para que o usuário possa experimentar imediatamente no celular ou adicionar mais.
    final checkIn1 = ForensicPhotoEvidence.verified(
      id: 'chk-in-1-$orderId',
      orderId: orderId,
      imagePathOrUrl: 'forensic://checkin/overview/$orderId',
      stage: ForensicStage.beforeCheckIn,
      capturedAt: now.subtract(const Duration(minutes: 40)),
      latitude: -18.9186,
      longitude: -48.2772,
      isGpsVerifiedAtAddress: true,
      captionOrTechnicalNote: 'Foto 1 (Antes): Visão geral do ponto antes da intervenção técnica.',
      amount: safeLabor,
    );
    final checkIn2 = ForensicPhotoEvidence.verified(
      id: 'chk-in-2-$orderId',
      orderId: orderId,
      imagePathOrUrl: 'forensic://checkin/detail/$orderId',
      stage: ForensicStage.beforeCheckIn,
      capturedAt: now.subtract(const Duration(minutes: 38)),
      latitude: -18.9186,
      longitude: -48.2772,
      isGpsVerifiedAtAddress: true,
      captionOrTechnicalNote: 'Foto 2 (Antes): Detalhe aproximado do componente danificado.',
      amount: safeLabor,
    );

    final sampleReceiptPhoto = ForensicPhotoEvidence.verified(
      id: 'nfce-photo-1-$orderId',
      orderId: orderId,
      imagePathOrUrl: 'forensic://receipt/nfce/$orderId',
      stage: ForensicStage.materialFiscalReceipt,
      capturedAt: now.subtract(const Duration(minutes: 25)),
      latitude: -18.9186,
      longitude: -48.2772,
      isGpsVerifiedAtAddress: true,
      captionOrTechnicalNote: 'Cupom Fiscal NFC-e anexado para reembolso integral (0% taxa).',
      amount: 90.00,
    );

    final sampleTicket = MaterialReimbursementTicket.validated(
      id: 'mat-1-$orderId',
      materialDescription: 'Kit Peças de Reposição Homologadas (ABNT/INMETRO)',
      storeName: 'Depósito ConstruFácil Materiais LTDA',
      fiscalReceiptNumber: 'NFC-e #000.482.910',
      receiptTotalAmount: 90.00,
      receiptPhoto: sampleReceiptPhoto,
      isApprovedByClient: true,
    );

    final created = OrderFintechDossierState(
      orderId: orderId,
      serviceCategoryName: serviceCategoryName,
      serviceTitle: serviceTitle,
      clientName: clientName,
      providerId: providerId,
      providerName: providerName,
      propertyAddress: propertyAddress,
      serviceLaborAmount: safeLabor,
      checkInBeforePhotos: [checkIn1, checkIn2],
      checkOutAfterPhotos: const <ForensicPhotoEvidence>[],
      reimbursedMaterials: [sampleTicket],
    );

    _state = _state.copyWith(
      orders: {..._state.orders, orderId: created},
    );
    return created;
  }

  OrderFintechDossierState addCheckInPhoto({
    required String orderId,
    required String imagePathOrUrl,
    required String captionOrTechnicalNote,
    double? latitude = -18.9186,
    double? longitude = -48.2772,
    bool isGpsVerifiedAtAddress = true,
  }) {
    final current = ensureOrder(orderId: orderId);
    final idx = current.checkInBeforePhotos.length + 1;
    final photo = ForensicPhotoEvidence.verified(
      id: 'chk-in-$idx-${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      imagePathOrUrl: imagePathOrUrl,
      stage: ForensicStage.beforeCheckIn,
      capturedAt: DateTime.now().toUtc(),
      latitude: latitude,
      longitude: longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress,
      captionOrTechnicalNote: captionOrTechnicalNote,
      amount: current.serviceLaborAmount,
    );
    final updated = current.copyWith(
      checkInBeforePhotos: [...current.checkInBeforePhotos, photo],
    );
    _state = _state.copyWith(orders: {..._state.orders, orderId: updated});
    notifyListeners();
    return updated;
  }

  OrderFintechDossierState addCheckOutPhoto({
    required String orderId,
    required String imagePathOrUrl,
    required String captionOrTechnicalNote,
    double? latitude = -18.9186,
    double? longitude = -48.2772,
    bool isGpsVerifiedAtAddress = true,
  }) {
    final current = ensureOrder(orderId: orderId);
    final idx = current.checkOutAfterPhotos.length + 1;
    final photo = ForensicPhotoEvidence.verified(
      id: 'chk-out-$idx-${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      imagePathOrUrl: imagePathOrUrl,
      stage: ForensicStage.afterCheckOut,
      capturedAt: DateTime.now().toUtc(),
      latitude: latitude,
      longitude: longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress,
      captionOrTechnicalNote: captionOrTechnicalNote,
      amount: current.splitBreakdown.grossTransactionAmount,
    );
    var updated = current.copyWith(
      checkOutAfterPhotos: [...current.checkOutAfterPhotos, photo],
    );
    _state = _state.copyWith(orders: {..._state.orders, orderId: updated});

    if (updated.isReadyToIssueCertificate && updated.certificate == null) {
      issueCertificate(orderId);
      updated = _state.orders[orderId]!;
    } else {
      notifyListeners();
    }
    return updated;
  }

  OrderFintechDossierState addMaterialReceipt({
    required String orderId,
    required String materialDescription,
    required String storeName,
    required String fiscalReceiptNumber,
    required double receiptTotalAmount,
    bool approvedByClient = true,
  }) {
    final current = ensureOrder(orderId: orderId);
    final safeAmount = SecurityAndLgpdGuard.validateAmount(receiptTotalAmount);
    final receiptPhoto = ForensicPhotoEvidence.verified(
      id: 'nfce-${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      imagePathOrUrl: 'forensic://receipt/$fiscalReceiptNumber',
      stage: ForensicStage.materialFiscalReceipt,
      capturedAt: DateTime.now().toUtc(),
      latitude: -18.9186,
      longitude: -48.2772,
      isGpsVerifiedAtAddress: true,
      captionOrTechnicalNote: 'Cupom Fiscal $fiscalReceiptNumber ($storeName)',
      amount: safeAmount,
    );
    final ticket = MaterialReimbursementTicket.validated(
      id: 'mat-${current.reimbursedMaterials.length + 1}-${DateTime.now().millisecondsSinceEpoch}',
      materialDescription: materialDescription,
      storeName: storeName,
      fiscalReceiptNumber: fiscalReceiptNumber,
      receiptTotalAmount: safeAmount,
      receiptPhoto: receiptPhoto,
      isApprovedByClient: approvedByClient,
    );
    final updated = current.copyWith(
      reimbursedMaterials: [...current.reimbursedMaterials, ticket],
    );
    _state = _state.copyWith(orders: {..._state.orders, orderId: updated});
    notifyListeners();
    return updated;
  }

  OrderFintechDossierState toggleMaterialReceiptApproval({
    required String orderId,
    required String ticketId,
  }) {
    final current = ensureOrder(orderId: orderId);
    final updatedList = current.reimbursedMaterials.map((m) {
      if (m.id == ticketId) {
        return m.copyWith(isApprovedByClient: !m.isApprovedByClient);
      }
      return m;
    }).toList();
    final updated = current.copyWith(reimbursedMaterials: updatedList);
    _state = _state.copyWith(orders: {..._state.orders, orderId: updated});
    notifyListeners();
    return updated;
  }

  /// Emite o Certificado Digital de Garantia exigindo mínimo de 2 fotos Antes e 2 fotos Depois.
  WarrantyCertificate issueCertificate(
    String orderId, {
    int warrantyDurationDays = 90,
  }) {
    final current = ensureOrder(orderId: orderId);
    if (current.checkInBeforePhotos.length < 2 ||
        current.checkOutAfterPhotos.length < 2) {
      throw StateError(
        'A emissão do Certificado exige no mínimo 2 fotos de Check-in (Antes) e 2 fotos de Check-out (Depois) com hash forense.',
      );
    }

    final now = DateTime.now().toUtc();
    final split = current.splitBreakdown;
    final shortOrder = orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final codeSuffix = shortOrder.length >= 5
        ? shortOrder.substring(0, 5)
        : shortOrder.padRight(5, 'X');
    final certCode = 'DSP-GAR-${now.year}-$codeSuffix';

    final secHash = SecurityAndLgpdGuard.generateForensicHash(
      orderId: orderId,
      stage: 'warranty_certificate_issued',
      timestampIso8601: now.toIso8601String(),
      latitude: current.checkOutAfterPhotos.first.latitude,
      longitude: current.checkOutAfterPhotos.first.longitude,
      amount: split.grossTransactionAmount,
    );

    final cert = WarrantyCertificate(
      certificateCode: certCode,
      securityVerificationHash: secHash,
      orderId: orderId,
      serviceCategoryName: current.serviceCategoryName,
      serviceTitle: current.serviceTitle,
      clientName: current.clientName,
      providerName: current.providerName,
      propertyAddress: current.propertyAddress,
      issuedAt: now,
      warrantyDurationDays: warrantyDurationDays,
      expiresAt: now.add(Duration(days: warrantyDurationDays)),
      checkInBeforePhotos: current.checkInBeforePhotos,
      checkOutAfterPhotos: current.checkOutAfterPhotos,
      reimbursedMaterials: current.reimbursedMaterials,
      financialBreakdown: split,
    );

    final updatedOrder = current.copyWith(certificate: cert);

    // Credita o aporte de 1,5% da mão de obra no Livro-Razão do Fundo de Reserva
    final newReserveBalance = SecurityAndLgpdGuard.roundCurrency(
      _state.reserveFundBalance + split.warrantyReserveContribution,
    );

    // Atualiza o Passaporte de Manutenção do Imóvel ("Prontuário da Casa")
    final existingEntries = _state.propertyPassport.entries
        .where((e) => e.orderId != orderId)
        .toList();
    final newEntry = PropertyMaintenanceEntry(
      id: 'pm-$orderId',
      orderId: orderId,
      certificateCode: certCode,
      serviceCategoryName: current.serviceCategoryName,
      serviceTitle: current.serviceTitle,
      providerName: current.providerName,
      completedAt: now,
      warrantyExpiresAt: cert.expiresAt,
      laborAmount: split.serviceLaborAmount,
      materialAmount: split.materialReimbursementAmount,
      forensicHash: secHash,
    );

    final updatedPassport = _state.propertyPassport.copyWith(
      updatedAt: now,
      entries: [newEntry, ...existingEntries],
    );

    _state = _state.copyWith(
      orders: {..._state.orders, orderId: updatedOrder},
      reserveFundBalance: newReserveBalance,
      propertyPassport: updatedPassport,
    );
    notifyListeners();
    return cert;
  }

  /// Aciona ou faz a transição entre as 3 Camadas da Garantia Desperrengue.
  /// Garante matematicamente que a alocação do Fundo de Reserva nunca ultrapasse
  /// `maxWarrantyCoverageCap` (100% da mão de obra) e lance o Clawback no infrator.
  WarrantyClaimTicket triggerWarrantyLayer({
    required String orderId,
    required WarrantyResolutionLayer layer,
    required String claimReason,
    double hoursSinceCompletion = 18.0,
    double? requestedRescueAmount,
    String rescueProviderId = 'prov-socorrista-99',
  }) {
    final current = ensureOrder(orderId: orderId);
    final split = current.splitBreakdown;
    final cap = split.maxWarrantyCoverageCap;
    final certCode = current.certificate?.certificateCode ?? 'DSP-GAR-PROV-$orderId';
    final now = DateTime.now().toUtc();

    late final WarrantyClaimTicket ticket;
    var updatedReserve = _state.reserveFundBalance;
    var updatedClawback = Map<String, double>.from(_state.providerClawbackLedger);

    switch (layer) {
      case WarrantyResolutionLayer.layer1ProviderFreeReturn:
        ticket = WarrantyClaimTicket(
          id: 'CLM-L1-$orderId',
          certificateCode: certCode,
          orderId: orderId,
          originalProviderId: current.providerId,
          currentLayer: WarrantyResolutionLayer.layer1ProviderFreeReturn,
          status: WarrantyClaimStatus.providerAssignedForReturn,
          claimReason: SecurityAndLgpdGuard.sanitizeInput(claimReason),
          reportedAt: now,
          hoursSinceServiceCompletion: hoursSinceCompletion,
          isOriginalProviderScheduleLocked: true,
          isEscrowWalletARetained: hoursSinceCompletion <= 48.0,
          reserveFundAllocatedAmount: 0.0,
          maxWarrantyCoverageCap: cap,
          clawbackDebitedFromOffender: 0.0,
          auditTrailNote:
              'Camada 1 acionada (Art. 20 CDC): Retorno gratuito obrigatório atribuído a ${current.providerName}. Agenda de novos chamados travada até conclusão.',
        );
      case WarrantyResolutionLayer.layer2EscrowHoldRetention:
        ticket = WarrantyClaimTicket(
          id: 'CLM-L2-$orderId',
          certificateCode: certCode,
          orderId: orderId,
          originalProviderId: current.providerId,
          currentLayer: WarrantyResolutionLayer.layer2EscrowHoldRetention,
          status: WarrantyClaimStatus.escrowRetained,
          claimReason: SecurityAndLgpdGuard.sanitizeInput(claimReason),
          reportedAt: now,
          hoursSinceServiceCompletion: hoursSinceCompletion,
          isOriginalProviderScheduleLocked: true,
          isEscrowWalletARetained: true,
          reserveFundAllocatedAmount: 0.0,
          maxWarrantyCoverageCap: cap,
          clawbackDebitedFromOffender: 0.0,
          auditTrailNote:
              'Camada 2 acionada (<48h): Repasse líquido da Carteira A (R\$ ${split.providerNetLaborPayout.toStringAsFixed(2)}) bloqueado preventivamente no Escrow.',
        );
      case WarrantyResolutionLayer.layer3ReserveFundRescue:
        final rawReq = requestedRescueAmount ?? cap;
        final safeReq = SecurityAndLgpdGuard.validateAmount(rawReq < 0 ? 0 : rawReq);
        // Trava estrita no teto máximo de 100% da mão de obra original (maxWarrantyCoverageCap)
        final allocated = safeReq > cap ? cap : safeReq;

        updatedReserve = SecurityAndLgpdGuard.roundCurrency(
          (_state.reserveFundBalance - allocated).clamp(0.0, double.infinity),
        );
        final prevDebt = updatedClawback[current.providerId] ?? 0.0;
        updatedClawback[current.providerId] =
            SecurityAndLgpdGuard.roundCurrency(prevDebt + allocated);

        ticket = WarrantyClaimTicket(
          id: 'CLM-L3-$orderId',
          certificateCode: certCode,
          orderId: orderId,
          originalProviderId: current.providerId,
          rescueProviderId: rescueProviderId,
          currentLayer: WarrantyResolutionLayer.layer3ReserveFundRescue,
          status: WarrantyClaimStatus.rescueProviderDispatched,
          claimReason: SecurityAndLgpdGuard.sanitizeInput(claimReason),
          reportedAt: now,
          hoursSinceServiceCompletion: hoursSinceCompletion,
          isOriginalProviderScheduleLocked: true,
          isEscrowWalletARetained: true,
          reserveFundAllocatedAmount: allocated,
          maxWarrantyCoverageCap: cap,
          clawbackDebitedFromOffender: allocated,
          auditTrailNote:
              'Camada 3 acionada: Prestador Socorrista ($rescueProviderId) remunerado pelo Fundo de Reserva de 1,5% em R\$ ${allocated.toStringAsFixed(2)} (Cap máx: R\$ ${cap.toStringAsFixed(2)}). Clawback registrado contra ${current.providerId}.',
        );
    }

    final updatedOrder = current.copyWith(activeClaimTicket: ticket);
    _state = _state.copyWith(
      orders: {..._state.orders, orderId: updatedOrder},
      reserveFundBalance: updatedReserve,
      providerClawbackLedger: updatedClawback,
    );
    notifyListeners();
    return ticket;
  }

  /// Configura os metadados oficiais do Imóvel no Passaporte (Padrão ABNT NBR 5674) pelo cliente.
  PropertyMaintenancePassport configurePropertyPassport({
    required String ownerName,
    required String propertyNickname,
    required String propertyAddress,
    required String propertyType,
    required String passportPurpose,
    required List<String> inspectedSystems,
  }) {
    final now = DateTime.now().toUtc();
    final safeOwner = SecurityAndLgpdGuard.sanitizeInput(ownerName);
    final safeNickname = SecurityAndLgpdGuard.sanitizeInput(propertyNickname);
    final safeAddress = SecurityAndLgpdGuard.sanitizeInput(propertyAddress);
    final safeType = SecurityAndLgpdGuard.sanitizeInput(propertyType);
    final safePurpose = SecurityAndLgpdGuard.sanitizeInput(passportPurpose);
    final safeSystems = inspectedSystems
        .map(SecurityAndLgpdGuard.sanitizeInput)
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final updatedPassport = _state.propertyPassport.copyWith(
      ownerName: safeOwner.isNotEmpty ? safeOwner : _state.propertyPassport.ownerName,
      propertyNickname: safeNickname.isNotEmpty ? safeNickname : 'Residência Principal',
      propertyAddress: safeAddress,
      propertyType: safeType.isNotEmpty ? safeType : 'Casa Residencial',
      passportPurpose: safePurpose.isNotEmpty
          ? safePurpose
          : 'Vistoria de Imobiliária / Entrega de Chaves',
      inspectedSystems: safeSystems,
      isConfiguredByClient: true,
      updatedAt: now,
    );

    _state = _state.copyWith(propertyPassport: updatedPassport);
    notifyListeners();
    return updatedPassport;
  }

  /// Registra uma manutenção real informada/homologada pelo próprio usuário cliente no Passaporte do Imóvel.
  PropertyMaintenanceEntry registerClientMaintenanceEntry({
    required String serviceCategoryName,
    required String serviceTitle,
    required String providerName,
    required double laborAmount,
    required double materialAmount,
    int warrantyDurationDays = 90,
    String? propertyAddress,
    String? ownerName,
  }) {
    final now = DateTime.now().toUtc();
    final safeCategory = SecurityAndLgpdGuard.sanitizeInput(serviceCategoryName);
    final safeTitle = SecurityAndLgpdGuard.sanitizeInput(serviceTitle);
    final safeProvider = SecurityAndLgpdGuard.sanitizeInput(providerName);
    final safeLabor = SecurityAndLgpdGuard.validateAmount(
      laborAmount < 0 ? 0.0 : laborAmount,
      fieldName: 'laborAmount',
    );
    final safeMaterial = SecurityAndLgpdGuard.validateAmount(
      materialAmount < 0 ? 0.0 : materialAmount,
      fieldName: 'materialAmount',
    );
    final safeDays = warrantyDurationDays.clamp(30, 1825);
    final seq = _state.propertyPassport.entries.length + 1;
    final seqTag = seq.toString().padLeft(3, '0');
    final orderId = 'PASS-REG-${now.year}-$seqTag';
    final certCode = 'DSP-PASS-${now.year}-$seqTag';
    final total = SecurityAndLgpdGuard.roundCurrency(safeLabor + safeMaterial);

    final hash = SecurityAndLgpdGuard.generateForensicHash(
      orderId: orderId,
      stage: 'client_verified_passport_entry',
      timestampIso8601: now.toIso8601String(),
      latitude: 0.0,
      longitude: 0.0,
      amount: total,
    );

    final entry = PropertyMaintenanceEntry(
      id: 'pm-client-${now.microsecondsSinceEpoch}-$seq',
      orderId: orderId,
      certificateCode: certCode,
      serviceCategoryName: safeCategory.isNotEmpty ? safeCategory : 'Manutenção Predial',
      serviceTitle: safeTitle.isNotEmpty ? safeTitle : 'Serviço Registrado pelo Cliente',
      providerName: safeProvider.isNotEmpty ? safeProvider : 'Profissional Homologado pelo Cliente',
      completedAt: now,
      warrantyExpiresAt: now.add(Duration(days: safeDays)),
      laborAmount: safeLabor,
      materialAmount: safeMaterial,
      forensicHash: hash,
    );

    final safeAddress = propertyAddress != null
        ? SecurityAndLgpdGuard.sanitizeInput(propertyAddress)
        : '';
    final safeOwner = ownerName != null
        ? SecurityAndLgpdGuard.sanitizeInput(ownerName)
        : '';

    final updatedPassport = _state.propertyPassport.copyWith(
      propertyAddress: safeAddress.isNotEmpty
          ? safeAddress
          : _state.propertyPassport.propertyAddress,
      ownerName: safeOwner.isNotEmpty
          ? safeOwner
          : _state.propertyPassport.ownerName,
      isConfiguredByClient: true,
      updatedAt: now,
      entries: <PropertyMaintenanceEntry>[
        entry,
        ..._state.propertyPassport.entries,
      ],
    );

    _state = _state.copyWith(propertyPassport: updatedPassport);
    notifyListeners();
    return entry;
  }

  /// Remove um registro manual inserido pelo cliente no Passaporte do Imóvel.
  PropertyMaintenancePassport removeClientMaintenanceEntry(String entryId) {
    final now = DateTime.now().toUtc();
    final filtered = _state.propertyPassport.entries
        .where((e) => e.id != entryId)
        .toList(growable: false);
    final updatedPassport = _state.propertyPassport.copyWith(
      entries: filtered,
      updatedAt: now,
    );
    _state = _state.copyWith(propertyPassport: updatedPassport);
    notifyListeners();
    return updatedPassport;
  }

  /// Sincroniza automaticamente o nome e o endereço real do perfil do cliente caso ainda não tenham sido configurados.
  PropertyMaintenancePassport syncPassportOwnerAndAddress({
    String? ownerName,
    String? propertyAddress,
  }) {
    final current = _state.propertyPassport;
    final safeOwner = ownerName != null ? SecurityAndLgpdGuard.sanitizeInput(ownerName) : '';
    final safeAddress = propertyAddress != null
        ? SecurityAndLgpdGuard.sanitizeInput(propertyAddress)
        : '';

    final nextOwner = current.ownerName.trim().isEmpty && safeOwner.isNotEmpty
        ? safeOwner
        : current.ownerName;
    final nextAddress = current.propertyAddress.trim().isEmpty && safeAddress.isNotEmpty
        ? safeAddress
        : current.propertyAddress;

    if (nextOwner == current.ownerName && nextAddress == current.propertyAddress) {
      return current;
    }

    final updatedPassport = current.copyWith(
      ownerName: nextOwner,
      propertyAddress: nextAddress,
      updatedAt: DateTime.now().toUtc(),
    );
    _state = _state.copyWith(propertyPassport: updatedPassport);
    notifyListeners();
    return updatedPassport;
  }
}
