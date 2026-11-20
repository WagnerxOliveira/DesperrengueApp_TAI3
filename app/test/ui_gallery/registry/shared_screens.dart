// Galeria de Telas — registro do GRUPO D (`features/shared/presentation/**`).
//
// NÃO registradas (e por quê):
//  * AchievementsScreen / AchievementsSection — `ProviderService()` em campo/build sem
//    injeção (`achievement_widgets.dart:379/322`); precisa de `loader`.
//  * ShowcaseStrip / CaseDetailScreen / CaseCurationScreen — `ProviderService()` +
//    FutureBuilder sem injeção (`showcase_widgets.dart:36/212/548`).
//  * MapaRotaServicoModal — `buildTileLayer` direto (tiles OSM por rede, L206) sem override.
//  * ProviderLocationBuilder — coberto por ProviderLocationPanel (só acrescenta Timer de desbloqueio).
//  * ProfilePhotoPreviewAndSaveDialog — exige `PickedImage` real (picker); coberto pelo viewer.
//  * Átomos internos (MedalBadge/MedalTile/AchievementTile, BadgeChips…) — cobertos pelas telas
//    que os usam.
import 'dart:async';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/account_models.dart';
import 'package:desperrengue_app/core/models/achievements.dart';
import 'package:desperrengue_app/core/models/chat_models.dart';
import 'package:desperrengue_app/core/models/client_achievements.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/models/smart_triage_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/security/zero_trust_bilateral_security_engine.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/services/smart_triage_service.dart';
import 'package:desperrengue_app/core/state/anti_bypass_fintech_controller.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/features/shared/presentation/achievement_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/chat_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';
import 'package:desperrengue_app/features/shared/presentation/delete_account_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/fintech_warranty_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/geo_privacy_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/live_location_map.dart';
import 'package:desperrengue_app/features/shared/presentation/notifications_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/profile_photo_viewer.dart';
import 'package:desperrengue_app/features/shared/presentation/review_thanks_view.dart';
import 'package:desperrengue_app/features/shared/presentation/review_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/role_terms_acceptance_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/scheduled_service_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/service_map_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/smart_triage_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/support_screens.dart';
import 'package:desperrengue_app/features/shared/presentation/theme_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../support/screen_gallery/screen_gallery.dart';

const String _owner = 'shared_ui';

/// Camada de tiles neutra (nenhuma rede).
Widget _tiles() => const ColoredBox(key: ValueKey('tile-fake'), color: Color(0xFFDCE6D8), child: SizedBox.expand());

// ---------------------------------------------------------------- chat

class _FakeChat implements ChatBackend {
  _FakeChat(this.items, {this.jobStatus = JobStatus.inProgress, this.peer});
  final List<ChatMessage> items;
  final JobStatus jobStatus;
  final ChatCounterpart? peer;

  @override
  String get currentUserId => 'user-me';

  @override
  Stream<List<ChatMessage>> messages(String jobId, String providerId) => Stream.value(items);

  @override
  Stream<Job?> job(String jobId) => Stream.value(SampleData.job(status: jobStatus, providerId: 'prov-1'));

  @override
  Future<ChatCounterpart?> counterpart(String jobId, String providerId) async => peer;

  @override
  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) async {}
}

List<ChatMessage> _chatItems() {
  final t0 = DateTime(2026, 10, 30, 8, 28);
  ChatMessage m(int id, String sender, String body, int min) => ChatMessage(
        id: id,
        jobId: 'job-1',
        providerId: 'prov-1',
        senderId: sender,
        kind: 'text',
        body: body,
        createdAt: t0.add(Duration(minutes: min)),
      );
  return <ChatMessage>[
    m(1, 'user-other', 'Bom dia! Vi o seu pedido de troca de disjuntor. Consigo passar hoje às 14h para avaliar o quadro de luz.', 0),
    m(2, 'user-me', 'Bom dia, João! Pode ser sim. O endereço é Rua das Acácias, 123 - Apto 45, Jardim América.', 3),
    m(3, 'user-other', 'Perfeito. Leve em conta que se o quadro for antigo posso precisar trocar também o barramento, o que muda o valor do orçamento.', 5),
    m(4, 'user-me', 'Ok', 6),
    m(5, 'user-other', 'Chego em 20 minutos.', 190),
  ];
}

GalleryScreen _chat(
  String suffix,
  String title, {
  List<ChatMessage>? items,
  bool readOnly = false,
  JobStatus status = JobStatus.inProgress,
}) =>
    GalleryScreen(
      id: 'shared/chat_screen$suffix',
      title: title,
      source: 'features/shared/presentation/chat_screen.dart',
      wave: 2,
      owner: _owner,
      modes: const <UserMode?>{UserMode.client, UserMode.provider},
      builder: (_, v) => ChatScreen(
        job: SampleData.job(status: status, providerId: 'prov-1'),
        providerId: 'prov-1',
        peerName: 'João Carlos Ferreira de Albuquerque',
        readOnly: readOnly,
        backend: _FakeChat(
          items ?? _chatItems(),
          jobStatus: status,
          peer: const ChatCounterpart(
            id: 'prov-1',
            role: 'provider',
            name: 'João Carlos Ferreira de Albuquerque',
            subtitle: 'Eletricista residencial · NR-10',
          ),
        ),
      ),
    );

// -------------------------------------------------------- notificações

List<AppNotification> _notifs() {
  final now = DateTime.now();
  return <AppNotification>[
    AppNotification(
      id: 'n1',
      kind: 'new_quote',
      title: 'Novo orçamento recebido para o seu pedido de troca de disjuntor',
      body: 'João Carlos Ferreira enviou R\$ 1.250,00 para o seu pedido. Toque para comparar com os demais orçamentos.',
      jobId: 'job-101',
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: 'n2',
      kind: 'new_invite',
      title: 'Nova oportunidade na sua região',
      body: 'Cliente precisa de reparo hidráulico.',
      jobId: 'job-202',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n3',
      kind: 'payment_released',
      title: 'Pagamento liberado',
      createdAt: now.subtract(const Duration(days: 3)),
      readAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

// ------------------------------------------------------------- geo

const String _geoCity = 'Poços de Caldas';

const ProviderLocationView _openView = ProviderLocationView(
  phase: GeoPrivacyPhase.openQuoting,
  exactUnlocked: false,
  city: _geoCity,
  uf: 'MG',
  neighborhood: 'Country Club',
  lat: -21.7871,
  lng: -46.5612,
  radiusM: 650,
);

final ProviderLocationView _futureView = ProviderLocationView(
  phase: GeoPrivacyPhase.confirmedFuture,
  exactUnlocked: false,
  city: _geoCity,
  uf: 'MG',
  neighborhood: 'Country Club',
  lat: -21.7871,
  lng: -46.5612,
  radiusM: 650,
  scheduledDate: DateTime.utc(2099, 1, 15),
  unlockAt: DateTime.utc(2099, 1, 15, 3),
);

const ProviderLocationView _serviceDayView = ProviderLocationView(
  phase: GeoPrivacyPhase.serviceDay,
  exactUnlocked: true,
  city: _geoCity,
  uf: 'MG',
  neighborhood: 'Country Club',
  street: 'Avenida Padre Cletus Oliveira de Albuquerque',
  number: '1661',
  complement: 'Apto 12, Bloco B',
  reference: 'Portão azul ao lado da padaria',
  cep: '37701-000',
  lat: -21.7869,
  lng: -46.5614,
  radiusM: 100,
);

const ProviderLocationView _closedView = ProviderLocationView(
  phase: GeoPrivacyPhase.closed,
  exactUnlocked: false,
  city: _geoCity,
  uf: 'MG',
  neighborhood: 'Country Club',
);

// ------------------------------------------------------ agendamento

const JobDestination _dest = JobDestination(
  lat: -21.78,
  lng: -46.56,
  precision: DestinationPrecision.exact,
  radiusM: 100,
  source: 'client_pin',
);

class _FakeSchedulingBackend implements SchedulingBackend {
  @override
  Future<DateTime> serverTime() async => DateTime.now();

  @override
  Future<JobDestination?> destination(String jobId) async => _dest;

  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) async =>
      StartResult(startedAt: DateTime.now(), simulated: simulate);

  @override
  Future<JobDestination?> setLocation(
    String jobId,
    double lat,
    double lng, {
    String source = 'client_pin',
    String precision = 'house',
  }) async =>
      _dest;
}

SchedulingDeps _schedDeps({ProviderLocationView? view}) => SchedulingDeps(
      backend: _FakeSchedulingBackend(),
      requestLocation: () async => LocationAccess.granted,
      positions: () => const Stream<GeoFix>.empty(),
      address: (_) async => <String, dynamic>{
        'address_line': 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        'reference': 'Portão azul',
      },
      clientCard: (_) async => <String, dynamic>{'full_name': 'Carla Souza'},
      peer: (_) async => (name: 'Paulo Eletricista Silva Santos', avatar: null),
      geocode: (_, _) async => null,
      location: (_) async => view,
    );

Job _scheduledJob(DateTime when, {JobStatus status = JobStatus.scheduled}) => Job(
      id: '11111111-2222-3333-4444-555555555555',
      clientId: 'c',
      title: 'Instalar chuveiro elétrico na suíte e revisar a fiação',
      description: 'Trocar o chuveiro da suíte.',
      category: 'Elétrica',
      status: status,
      paymentStatus: 'escrow',
      urgency: 'scheduled',
      visibility: 'direct',
      createdAt: DateTime(2026, 10, 29),
      providerId: 'p',
      agreedPrice: 1850,
      scheduledFor: when,
    );

// ---------------------------------------------------------- triagem

SmartTriageResult _triage() => SmartTriageService.instance.analyze(
      rawText: 'Cheiro forte de gás no fogão e mangueira vencida, também o disjuntor desarma quando ligo o chuveiro',
    );

// ------------------------------------------------------------- fintech

OrderFintechDossierState _dossier() => FintechLedgerStore.instance.ensureOrder(
      orderId: 'ORD-GAL-1',
      serviceLaborAmount: 1850.00,
    );

Widget _scroll(Widget child) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: child);

List<GalleryScreen> sharedScreens() => <GalleryScreen>[
      // ------------------------------------------------------------ chat
      _chat('', 'Chat (conversa)'),
      _chat('_vazio', 'Chat (sem mensagens)', items: const <ChatMessage>[]),
      _chat('_leitura', 'Chat (somente leitura)', readOnly: true, status: JobStatus.completed),

      // -------------------------------------------------- notificações
      GalleryScreen(
        id: 'shared/notifications',
        title: 'Notificações (lista)',
        source: 'features/shared/presentation/notifications_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => NotificationsScreen(onOpenJob: (_, _) {}, notificationsStream: Stream.value(_notifs())),
      ),
      GalleryScreen(
        id: 'shared/notifications_vazio',
        title: 'Notificações (vazio)',
        source: 'features/shared/presentation/notifications_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => NotificationsScreen(
          onOpenJob: (_, _) {},
          notificationsStream: Stream.value(const <AppNotification>[]),
        ),
      ),
      GalleryScreen(
        id: 'shared/notifications_erro',
        title: 'Notificações (erro)',
        source: 'features/shared/presentation/notifications_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => NotificationsScreen(
          onOpenJob: (_, _) {},
          notificationsStream: Stream<List<AppNotification>>.error(StateError('sem rede')),
        ),
      ),
      GalleryScreen(
        id: 'shared/unread_bell',
        title: 'Sininho de notificações',
        source: 'features/shared/presentation/notifications_screen.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => Align(
          alignment: Alignment.topRight,
          child: UnreadBell(onOpenJob: (_, _) {}, notificationsStream: Stream.value(_notifs())),
        ),
      ),

      // ------------------------------------------------------ conquistas
      GalleryScreen(
        id: 'shared/client_achievements',
        title: 'Conquistas do cliente (cheio)',
        source: 'features/shared/presentation/achievement_widgets.dart',
        wave: 2,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => ClientAchievementsScreen(
          profile: SampleData.clientProfile(),
          loader: () async => ClientAchievementInput(
            jobs: <Job>[
              for (var i = 0; i < 12; i++)
                SampleData.job(
                  id: 'job-$i',
                  status: JobStatus.completed,
                  paymentStatus: 'released',
                  category: i.isEven ? 'Elétrica' : 'Hidráulica',
                ),
            ],
            profileSteps: 4,
            reviewedJobIds: const <String>{'job-0', 'job-1', 'job-2'},
          ),
        ),
      ),
      GalleryScreen(
        id: 'shared/client_achievements_vazio',
        title: 'Conquistas do cliente (novo)',
        source: 'features/shared/presentation/achievement_widgets.dart',
        wave: 2,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => ClientAchievementsScreen(
          profile: SampleData.firstAccessProfile(),
          loader: () async => const ClientAchievementInput(jobs: <Job>[]),
        ),
      ),
      GalleryScreen(
        id: 'shared/client_achievements_erro',
        title: 'Conquistas do cliente (erro)',
        source: 'features/shared/presentation/achievement_widgets.dart',
        wave: 2,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => ClientAchievementsScreen(
          profile: SampleData.clientProfile(),
          loader: () async => throw StateError('falha simulada'),
        ),
      ),
      GalleryScreen(
        id: 'shared/new_achievements_banner',
        title: 'Banner de conquista desbloqueada',
        source: 'features/shared/presentation/achievement_widgets.dart',
        wave: 1,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _scroll(NewAchievementsBanner(achievements: <Achievement>[
          Achievement(kAchievementCategories[0], 1),
          Achievement(kAchievementCategories[6], 10000),
        ])),
      ),

      // --------------------------------------------------- KYC / termos
      GalleryScreen(
        id: 'shared/criminal_check_step',
        title: 'Antecedentes criminais (passo)',
        source: 'features/shared/presentation/criminal_background_check_step.dart',
        wave: 1,
        owner: 'auth_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{null},
        builder: (_, _) => _scroll(CriminalBackgroundCheckStep(
          expectedFullName: 'Maria Fernanda de Albuquerque e Souza Nascimento',
          expectedCpfRaw: '119.787.236-10',
          referenceNow: DateTime(2026, 10, 1),
          customUrlLauncher: (_) async {},
          customCertificatePicker: () async => (bytes: Uint8List(0), fileName: 'certidao.pdf'),
          onValidated: (_) {},
        )),
      ),
      GalleryScreen(
        id: 'shared/criminal_check_step_renovacao',
        title: 'Antecedentes criminais (renovação semestral)',
        source: 'features/shared/presentation/criminal_background_check_step.dart',
        wave: 1,
        owner: 'auth_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{null},
        builder: (_, _) => _scroll(CriminalBackgroundCheckStep(
          expectedFullName: 'João Carlos Ferreira',
          expectedCpfRaw: '119.787.236-10',
          isSixMonthRenewal: true,
          referenceNow: DateTime(2026, 10, 1),
          customUrlLauncher: (_) async {},
          customCertificatePicker: () async => null,
          onValidated: (_) {},
        )),
      ),
      GalleryScreen(
        id: 'shared/criminal_status',
        title: 'Status de antecedentes (verificado)',
        source: 'features/shared/presentation/criminal_background_check_step.dart',
        wave: 1,
        owner: 'auth_ui',
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => CriminalBackgroundStatusScreen(
          profile: UserProfile.fromMap(<String, dynamic>{
            'id': 'status-screen-user',
            'full_name': 'Wagner Oliveira',
            'verified_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
            'criminal_record_verified': true,
            'criminal_certificate_number_masked': 'PF-***1735',
          }),
          onRequestRenewal: () {},
        ),
      ),
      GalleryScreen(
        id: 'shared/role_terms_provider',
        title: 'Termos do papel (ativar profissional)',
        source: 'features/shared/presentation/role_terms_acceptance_screen.dart',
        wave: 1,
        owner: 'auth_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => RoleTermsAcceptanceScreen(
          profile: SampleData.clientProfile(),
          mode: UserMode.provider,
          customActivator: (_) async {},
        ),
      ),
      GalleryScreen(
        id: 'shared/role_terms_client',
        title: 'Termos do papel (ativar cliente)',
        source: 'features/shared/presentation/role_terms_acceptance_screen.dart',
        wave: 1,
        owner: 'auth_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => RoleTermsAcceptanceScreen(
          profile: SampleData.providerProfile(),
          mode: UserMode.client,
          isReuseFastTrack: false,
          customActivator: (_) async {},
        ),
      ),

      // -------------------------------------------------- excluir conta
      GalleryScreen(
        id: 'shared/delete_account',
        title: 'Excluir conta (livre)',
        source: 'features/shared/presentation/delete_account_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => DeleteAccountScreen(
          asProvider: v.mode == UserMode.provider,
          email: 'maria.fernanda.albuquerque@exemplo.com.br',
          statusLoader: (_) async => const DeletionStatus(available: 0, held: 0, activeJobs: 0, blockers: <String>[]),
          profileLoader: () async => SampleData.clientProfile(provider: false),
        ),
      ),
      GalleryScreen(
        id: 'shared/delete_account_dois_perfis',
        title: 'Excluir conta (cliente e profissional)',
        source: 'features/shared/presentation/delete_account_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => DeleteAccountScreen(
          asProvider: true,
          email: 'joao@exemplo.com.br',
          statusLoader: (_) async => const DeletionStatus(available: 0, held: 0, activeJobs: 0, blockers: <String>[]),
          profileLoader: () async => SampleData.clientProfile(provider: true),
        ),
      ),
      GalleryScreen(
        id: 'shared/delete_account_bloqueada',
        title: 'Excluir conta (bloqueada por saldo e custódia)',
        source: 'features/shared/presentation/delete_account_screen.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => DeleteAccountScreen(
          email: 'ana@exemplo.com.br',
          statusLoader: (_) async => const DeletionStatus(
            available: 12345.67,
            held: 4500,
            activeJobs: 3,
            blockers: <String>['balance', 'escrow', 'active_jobs'],
          ),
          profileLoader: () async => SampleData.clientProfile(),
        ),
      ),

      // --------------------------------------------------- fintech
      GalleryScreen(
        id: 'shared/smart_split_card',
        title: 'Card Smart Split (transparência)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => _scroll(SmartSplitTransparencyCard(dossier: _dossier(), isProviderView: v.mode == UserMode.provider)),
      ),
      GalleryScreen(
        id: 'shared/forensic_checkinout_card',
        title: 'Card check-in/out forense',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => _scroll(ForensicCheckInOutCard(dossier: _dossier(), isProviderView: v.mode == UserMode.provider)),
      ),
      GalleryScreen(
        id: 'shared/property_passport_view',
        title: 'Passaporte do imóvel (resumo)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => _scroll(PropertyPassportView(passport: FintechLedgerStore.instance.state.propertyPassport)),
      ),
      GalleryScreen(
        id: 'shared/property_passport_screen',
        title: 'Passaporte do imóvel (tela)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => const PropertyPassportScreen(
          initialOwnerName: 'Maria Fernanda de Albuquerque e Souza Nascimento',
          initialAddress: 'Rua das Acácias, 123 - Apto 45, Jardim América, São Paulo - SP',
        ),
      ),
      GalleryScreen(
        id: 'shared/property_passport_wizard',
        title: 'Passaporte do imóvel (assistente)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => const PropertyPassportWizardScreen(
          initialOwnerName: 'Ana Paula Souza',
          initialAddress: 'Rua das Acácias, 123 - Apto 45, Jardim América, São Paulo - SP',
        ),
      ),
      GalleryScreen(
        id: 'shared/warranty_three_layer_sheet',
        title: 'Sheet de garantia em 3 camadas',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 3,
        owner: _owner,
        kind: GalleryKind.sheet,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => const WarrantyThreeLayerResolutionSheet(orderId: 'ORD-GAL-1'),
      ),
      GalleryScreen(
        id: 'shared/mediation_timeline',
        title: 'Linha do tempo da mediação (5 fases)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => _scroll(const MediationFivePhaseTimeline(currentPhaseIndex: 2, originalLaborCap: 12800.0)),
      ),
      GalleryScreen(
        id: 'shared/forensic_split_comparator',
        title: 'Comparador forense antes/depois',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => _scroll(const ForensicSplitViewComparator(
          beforePhash64: 0x11223344,
          afterPhash64: 0x778899AA,
          defectPhash64: 0x5566,
          hammingBeforeAfter: 26,
          gpsDistanceMeters: 12.4,
        )),
      ),
      GalleryScreen(
        id: 'shared/pin_four_digit_card',
        title: 'Aprovação por PIN de 4 dígitos',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => _scroll(PinFourDigitApprovalCard(
          initialRemaining: const Duration(hours: 23, minutes: 59),
          materialScope: MaterialSplitScopeKind.componentReplacement,
          applianceNameplateOcr: 'CONSUL CRM50 • S/N 99881122',
          oldPartLeavePhotoPhash64: 0x9999AAAABBBBCCCC,
          onConfirmPin: (_) {},
        )),
      ),
      GalleryScreen(
        id: 'shared/marco_zero_trust_badge',
        title: 'Selo Marco Zero (confiança)',
        source: 'features/shared/presentation/fintech_warranty_widgets.dart',
        wave: 2,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _scroll(const Column(children: <Widget>[
          MarcoZeroTrustBadge(isTrustedAnchor: false, completedJobsCount: 0, rtsScore: 70.0),
          SizedBox(height: 12),
          MarcoZeroTrustBadge(isTrustedAnchor: true, completedJobsCount: 1248, rtsScore: 99.5),
        ])),
      ),

      // ------------------------------------------------- privacidade geo
      for (final e in <(String, String, ProviderLocationView)>[
        ('aberto', 'Localização protegida (cotação)', _openView),
        ('futuro', 'Localização protegida (agendado)', _futureView),
        ('dia_servico', 'Localização liberada (dia do serviço)', _serviceDayView),
        ('encerrado', 'Localização encerrada', _closedView),
      ])
        GalleryScreen(
          id: 'shared/provider_location_panel_${e.$1}',
          title: e.$2,
          source: 'features/shared/presentation/geo_privacy_widgets.dart',
          wave: 3,
          owner: _owner,
          kind: GalleryKind.widget,
          modes: const <UserMode?>{UserMode.provider},
          builder: (_, _) => _scroll(ProviderLocationPanel(view: e.$3, tileLayerOverride: _tiles())),
        ),
      GalleryScreen(
        id: 'shared/provider_location_pending',
        title: 'Localização (carregando)',
        source: 'features/shared/presentation/geo_privacy_widgets.dart',
        wave: 3,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _scroll(const Column(children: <Widget>[
          ProviderLocationPending(loading: true),
          SizedBox(height: 12),
          ProviderLocationPending(loading: false),
        ])),
      ),
      GalleryScreen(
        id: 'shared/protected_area_map_sheet',
        title: 'Mapa da área protegida (sheet)',
        source: 'features/shared/presentation/geo_privacy_widgets.dart',
        wave: 3,
        owner: _owner,
        kind: GalleryKind.sheet,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ProtectedAreaMapSheet(view: _futureView, tileLayerOverride: _tiles()),
      ),

      // ------------------------------------------------------ mapas
      GalleryScreen(
        id: 'shared/live_location_map_sheet',
        title: 'Mapa ao vivo (sheet)',
        source: 'features/shared/presentation/live_location_map.dart',
        wave: 3,
        owner: _owner,
        kind: GalleryKind.sheet,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => FractionallySizedBox(
          heightFactor: 0.92,
          child: LiveLocationMapSheet(
            addressLine: 'Rua Padre José Geraldi de Albuquerque, 203 - Maria Imaculada, Poços de Caldas - MG',
            latitude: -21.78,
            longitude: -46.56,
            positionStream: () => Stream<GeoFix>.value(const GeoFix(-21.7809, -46.56, accuracyM: 12)),
            tileLayer: _tiles(),
          ),
        ),
      ),
      GalleryScreen(
        id: 'shared/order_live_map',
        title: 'Mapa do pedido (tela cheia)',
        source: 'features/shared/presentation/order_live_map_modal_screen.dart',
        wave: 3,
        owner: _owner,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => OrderLiveMapModalScreen(
          addressLine: 'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
          latitude: -21.7878,
          longitude: -46.5614,
          providerOrigin: const LatLng(-21.7800, -46.5550),
          orderStatus: 'in_progress',
          onAdjustPin: (_, _) async {},
        ),
      ),
      GalleryScreen(
        id: 'shared/interactive_location_preview',
        title: 'Prévia interativa do local',
        source: 'features/shared/presentation/order_live_map_modal_screen.dart',
        wave: 3,
        owner: 'client_core_ui',
        kind: GalleryKind.widget,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => _scroll(const InteractiveLocationPreviewCard(
          addressLine: 'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
          latitude: -21.7878,
          longitude: -46.5614,
        )),
      ),
      GalleryScreen(
        id: 'shared/location_picker_sheet',
        title: 'Seletor de localização (pino)',
        source: 'features/shared/presentation/service_map_widgets.dart',
        wave: 3,
        owner: _owner,
        kind: GalleryKind.sheet,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => FractionallySizedBox(
          heightFactor: 0.92,
          child: LocationPickerSheet(
            initial: _dest,
            addressLine: 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
            tileLayer: _tiles(),
            reverseGeocoder: (lat, lng, {fallbackLine}) async => null,
            onConfirm: (_, _) async {},
          ),
        ),
      ),

      // -------------------------------------------------- foto de perfil
      GalleryScreen(
        id: 'shared/editable_avatar',
        title: 'Avatar editável',
        source: 'features/shared/presentation/profile_photo_viewer.dart',
        wave: 1,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => const Center(child: EditableAvatar(url: null, name: 'Maria Fernanda de Albuquerque', radius: 56, verified: true)),
      ),
      GalleryScreen(
        id: 'shared/profile_photo_viewer_sem_foto',
        title: 'Visualizador de foto (sem foto)',
        source: 'features/shared/presentation/profile_photo_viewer.dart',
        wave: 1,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => ProfilePhotoViewerScreen(url: null, name: 'Maria Fernanda de Albuquerque e Souza', changer: (_) async => null),
      ),

      // ------------------------------------------------------ avaliações
      for (final e in <(String, String, bool, bool)>[
        ('cliente', 'Obrigado (cliente, avaliação oculta)', false, false),
        ('cliente_revelada', 'Obrigado (cliente, avaliação revelada)', false, true),
        ('profissional', 'Obrigado (profissional)', true, false),
      ])
        GalleryScreen(
          id: 'shared/review_thanks_${e.$1}',
          title: e.$2,
          source: 'features/shared/presentation/review_thanks_view.dart',
          wave: 1,
          owner: _owner,
          modes: <UserMode?>{e.$3 ? UserMode.provider : UserMode.client},
          builder: (_, _) => Scaffold(body: ReviewThanksView(isProvider: e.$3, revealed: e.$4, onBack: () {})),
        ),
      GalleryScreen(
        id: 'shared/review_card',
        title: 'Cartões de avaliação',
        source: 'features/shared/presentation/review_widgets.dart',
        wave: 1,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => _scroll(Column(children: <Widget>[
          ReviewCard(
            review: PublicReview(
              id: 'r1',
              rating: 5,
              reviewerName: 'Maria Fernanda de Albuquerque S.',
              createdAt: DateTime(2026, 10, 12),
              comment:
                  'Serviço impecável: chegou no horário, explicou tudo sobre o quadro de luz, deixou a casa limpa e ainda me ajudou a entender a conta de energia. Recomendo muito!',
              tags: const <String>['Super pontual', 'Limpou tudo depois'],
              reply: 'Muito obrigado pela confiança, Maria! Foi um prazer atender.',
              replyAt: DateTime(2026, 10, 13),
            ),
            onOpenDetails: () {},
          ),
          const SizedBox(height: 12),
          ReviewCard(
            review: PublicReview(id: 'r2', rating: 3, reviewerName: 'Carlos', createdAt: DateTime(2026, 9, 1), comment: 'Ok.'),
          ),
        ])),
      ),
      GalleryScreen(
        id: 'shared/badge_wall',
        title: 'Mural de selos',
        source: 'features/shared/presentation/review_widgets.dart',
        wave: 1,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => _scroll(const BadgeWall(
          earned: <String>['super'],
          tagCounts: <String, int>{'Super pontual': 14, 'Limpou tudo depois': 6},
          fiveStarCount: 17,
          showProgress: true,
        )),
      ),

      // ------------------------------------------------------ agendamento
      GalleryScreen(
        id: 'shared/scheduled_service_futuro_cliente',
        title: 'Serviço agendado (cliente, futuro)',
        source: 'features/shared/presentation/scheduled_service_screen.dart',
        wave: 3,
        owner: _owner,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => ScheduledServiceScreen(
          job: _scheduledJob(DateTime.now().add(const Duration(days: 2, hours: 3))),
          asProvider: false,
          deps: _schedDeps(),
        ),
      ),
      GalleryScreen(
        id: 'shared/scheduled_service_hoje_profissional',
        title: 'Serviço agendado (profissional, hoje)',
        source: 'features/shared/presentation/scheduled_service_screen.dart',
        wave: 3,
        owner: _owner,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ScheduledServiceScreen(
          job: _scheduledJob(DateTime.now()),
          asProvider: true,
          deps: _schedDeps(view: _serviceDayView),
        ),
      ),
      GalleryScreen(
        id: 'shared/scheduled_service_travado_profissional',
        title: 'Serviço agendado (profissional, endereço protegido)',
        source: 'features/shared/presentation/scheduled_service_screen.dart',
        wave: 3,
        owner: _owner,
        animatesForever: true,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ScheduledServiceScreen(
          job: _scheduledJob(DateTime.now().add(const Duration(days: 3))),
          asProvider: true,
          deps: _schedDeps(view: _futureView),
        ),
      ),

      // -------------------------------------------------------- triagem
      GalleryScreen(
        id: 'shared/smart_triage_trigger_bar',
        title: 'Barra de acionamento da triagem',
        source: 'features/shared/presentation/smart_triage_widgets.dart',
        wave: 1,
        owner: 'client_core_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => _scroll(Column(children: <Widget>[
          SmartTriageTriggerBar(hasResult: false, analyzing: false, onTrigger: () {}),
          const SizedBox(height: 12),
          SmartTriageTriggerBar(hasResult: false, analyzing: true, onTrigger: () {}),
          const SizedBox(height: 12),
          SmartTriageTriggerBar(hasResult: true, analyzing: false, onTrigger: () {}),
        ])),
      ),
      GalleryScreen(
        id: 'shared/smart_triage_card',
        title: 'Card de triagem inteligente (emergência)',
        source: 'features/shared/presentation/smart_triage_widgets.dart',
        wave: 1,
        owner: 'client_core_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) {
          final r = _triage();
          return _scroll(Column(children: <Widget>[
            EmergencyContainmentBanner(guide: r.containmentGuide!, onToggleStep: (_) {}),
            const SizedBox(height: 12),
            SmartTriageCard(result: r, selectedCategory: 'Elétrica', onApplyCategory: (_) {}, onToggleMaterial: (_) {}),
          ]));
        },
      ),
      GalleryScreen(
        id: 'shared/provider_triage_brief',
        title: 'Resumo de triagem (profissional)',
        source: 'features/shared/presentation/smart_triage_widgets.dart',
        wave: 1,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _scroll(ProviderTriageBriefCard(result: _triage())),
      ),

      // -------------------------------------------------------- suporte
      GalleryScreen(
        id: 'shared/support_center',
        title: 'Central de ajuda (chamados e disputas)',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => SupportCenterScreen(
          asProvider: v.mode == UserMode.provider,
          ticketsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '9f8e7d6c-5b4a-4321-8abc-0123456789ab',
              'status': 'in_review',
              'reason': 'O profissional não compareceu no horário combinado e não respondeu às mensagens',
              'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
            },
            <String, dynamic>{
              'id': '1a2b3c4d-5e6f-4789-8abc-0123456789ab',
              'status': 'resolved',
              'reason': 'Dúvida sobre pagamento',
              'resolution': 'Reembolso integral em até 2 dias úteis.',
              'created_at': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
            },
          ],
          disputesLoader: () async => <Job>[SampleData.job(status: JobStatus.disputed, providerId: 'prov-1', price: 1850)],
          onOpenMediation: (_, _) {},
        ),
      ),
      GalleryScreen(
        id: 'shared/support_center_vazio',
        title: 'Central de ajuda (vazia)',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => SupportCenterScreen(
          ticketsLoader: () async => const <Map<String, dynamic>>[],
          disputesLoader: () async => const <Job>[],
        ),
      ),
      GalleryScreen(
        id: 'shared/support_center_erro',
        title: 'Central de ajuda (erro)',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => SupportCenterScreen(
          ticketsLoader: () async => throw StateError('sem rede'),
          disputesLoader: () async => const <Job>[],
        ),
      ),
      GalleryScreen(
        id: 'shared/report_problem_job',
        title: 'Relatar problema (com pedido)',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => ReportProblemScreen(
          job: SampleData.job(status: JobStatus.inProgress, providerId: 'prov-1'),
          asProvider: v.mode == UserMode.provider,
        ),
      ),
      GalleryScreen(
        id: 'shared/report_problem_geral',
        title: 'Relatar problema (geral)',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) => const ReportProblemScreen(asProvider: false),
      ),
      GalleryScreen(
        id: 'shared/ticket_created',
        title: 'Chamado criado',
        source: 'features/shared/presentation/support_screens.dart',
        wave: 2,
        owner: _owner,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, v) => TicketCreatedScreen(
          ticketId: '9f8e7d6c-5b4a-4321-8abc-0123456789ab',
          hasJob: true,
          asProvider: v.mode == UserMode.provider,
        ),
      ),

      // -------------------------------------------------------- aparência
      GalleryScreen(
        id: 'shared/appearance_tile',
        title: 'Linha de aparência (tema)',
        source: 'features/shared/presentation/theme_picker.dart',
        wave: 1,
        owner: _owner,
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (context, v) {
          final tk = context.tk;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppearanceTile(
              accent: v.mode == UserMode.provider ? tk.providerAccent : tk.clientAccent,
              soft: v.mode == UserMode.provider ? tk.providerSoft : tk.clientSoft,
              kind: v.mode == UserMode.provider ? ProfileMenuIconKind.providerAppearance : ProfileMenuIconKind.clientAppearance,
            ),
          );
        },
      ),
    ];
