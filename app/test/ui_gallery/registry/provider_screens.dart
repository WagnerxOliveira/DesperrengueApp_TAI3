import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_dossier_models.dart';
import 'package:desperrengue_app/core/models/provider_portfolio_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/services/provider_service.dart' show WalletSummary;
import 'package:desperrengue_app/core/state/provider_portfolio_controller.dart';
import 'package:desperrengue_app/core/ui/app_scaffold.dart';
import 'package:desperrengue_app/core/ui/image_picking.dart';
import 'package:desperrengue_app/core/ui/media_widgets.dart';
import 'package:desperrengue_app/core/ui/widgets.dart';
import 'package:desperrengue_app/features/provider/presentation/dossie_servico_profissional_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/material_receipt_capture_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/pix_withdraw_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_execution_screens.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_job_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_portfolio_widgets.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_profile_screens.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_setup_screens.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_shell.dart';
import 'package:desperrengue_app/features/provider/presentation/wallet_tab.dart';
import 'package:flutter/material.dart';

import '../../support/screen_gallery/screen_gallery.dart';

// ---------------------------------------------------------------------------
// Ganchos §5.1 entregues na Onda 4: ServiceExecutionScreen, ProviderJobScreen,
// ProviderDashboardTab e ProviderShell agora estão registrados abaixo.
// Pendente apenas: MaterialReceiptCaptureScreen em estados pós-captura (exige
// FiscalReceiptService mockado por tela).
//      toque no picker (registrado só o estado inicial).
// ---------------------------------------------------------------------------

const String _longJobTitle = 'Instalação completa de chuveiro elétrico 7.500 W com revisão do quadro de luz e troca de disjuntor bipolar';
const String _longClientName = 'Maria Fernanda de Albuquerque e Souza Nascimento';

Job _job(
  JobStatus status, {
  double price = 1234.56,
  String title = _longJobTitle,
  String payment = 'escrow',
}) =>
    SampleData.job(
      status: status,
      title: title,
      price: price,
      providerId: SampleData.providerId,
      paymentStatus: payment,
    );

Map<String, dynamic> _dossierMap({String status = 'completed', bool review = true, bool longText = true}) => <String, dynamic>{
      'job_id': '1a2b3c4d-0000-0000-0000-000000000001',
      'code': '#DSP-1A2B3',
      'status': status,
      'payment_status': status == 'completed' ? 'released' : 'escrow',
      'title': longText ? _longJobTitle : 'Troca de chuveiro',
      'description': longText
          ? 'O chuveiro queimou e precisa de troca. O disjuntor desarma quando ligo o forno ao mesmo tempo. '
              'Preciso de alguém para revisar o quadro de luz com segurança e deixar tudo documentado.'
          : 'Chuveiro queimou e precisa de troca.',
      'category': 'Elétrica',
      'address_line': 'Rua das Acácias, 123',
      'complement': 'Apto 45, Bloco B',
      'reference': 'Perto da padaria',
      'address_summary': 'Jardim América',
      'scheduled_for': '2026-10-20T14:00:00Z',
      'started_at': '2026-10-20T14:10:00Z',
      'started_simulated': false,
      'finished_at': '2026-10-20T15:00:00Z',
      'gross': 12345.67,
      'fee': 1481.48,
      'fee_pct': 12,
      'net': 10864.19,
      'client': <String, dynamic>{'id': 'c1', 'name': _longClientName, 'avatar_url': null},
      'report': 'Troquei o chuveiro, reapertei as conexões do quadro, testei o disjuntor e a corrente com alicate amperímetro. '
          'Tudo dentro da norma NBR 5410.',
      'photo_paths': <String>[],
      'evidence': <Map<String, dynamic>>[],
      'review': review
          ? <String, dynamic>{
              'state': 'revealed',
              'rating': 5,
              'tags': <String>['Super pontual', 'Capricho no acabamento'],
              'comment': 'Excelente profissional! Explicou tudo com calma e deixou a casa limpa, recomendo muito.',
              'reply': 'Obrigado pela confiança, foi um prazer atender!',
              'created_at': '2026-10-21T10:00:00Z',
            }
          : null,
    };

ProviderLocationView get _closedLocation => const ProviderLocationView(
      phase: GeoPrivacyPhase.closed,
      exactUnlocked: false,
      city: 'Poços de Caldas',
      uf: 'MG',
      neighborhood: 'Centro',
    );

Widget _dossier({
  String status = 'completed',
  bool review = true,
  bool fail = false,
  bool nullResult = false,
}) =>
    DossieServicoProfissionalScreen(
      jobId: 'j1',
      loader: (_) async {
        if (fail) throw StateError('falha simulada');
        if (nullResult) return null;
        return ProviderJobDossier.fromMap(_dossierMap(status: status, review: review));
      },
      locationLoader: (_) async => _closedLocation,
      openChat: (context, d) async {},
      imageBuilder: (context, path, {width, height, fit = BoxFit.cover, radius = 12}) =>
          SizedBox(width: width, height: height),
    );

Payment _payment(int i, double amount, {String status = 'released'}) => Payment(
      id: 'pay$i',
      jobId: 'j$i',
      amount: amount,
      feeAmount: amount * 0.12,
      netAmount: amount * 0.88,
      method: 'pix',
      status: status,
      createdAt: DateTime(2026, 10, 20 + i, 15),
      releasedAt: status == 'released' ? DateTime(2026, 10, 20 + i, 16) : null,
    );

WalletData _walletFull() {
  final payments = <Payment>[
    _payment(1, 12345.67),
    _payment(2, 980.00, status: 'escrow'),
    _payment(3, 150.00),
    _payment(4, 99999.99),
  ];
  final jobs = <String, Job>{
    for (var i = 1; i <= 4; i++)
      'j$i': SampleData.job(
        id: 'j$i',
        status: i == 2 ? JobStatus.inProgress : JobStatus.completed,
        title: i.isOdd ? _longJobTitle : 'Troca de tomada',
        price: payments[i - 1].amount,
        providerId: SampleData.providerId,
      ),
  };
  return (payments, jobs, 5432.10);
}

// ------------------------------------------------------------- portfólio

CompletedServiceRecord _record(int n, {bool reviewed = true, String? title}) => CompletedServiceRecord(
      id: 'srv-$n',
      orderId: 'ord-$n',
      title: title ?? (n.isOdd ? _longJobTitle : 'Troca de tomada #$n'),
      categoryName: 'Elétrica',
      clientRequestedDescription:
          'O cliente solicitou reparo elétrico completo #$n, incluindo revisão do quadro de luz e troca de disjuntores.',
      detailedExecutionReport:
          'Relatório técnico completo do serviço #$n: troca de disjuntor bipolar 40 A, reaperto de bornes e teste de corrente.',
      cityAndState: 'Poços de Caldas - MG',
      completedAt: DateTime(2026, 10, 1 + n, 10, n),
      validatedClientPin: (1000 + n).toString(),
      serviceValue: 1500.0 + n * 200,
      executionDurationText: '1h 15min',
      toolsAndMaterialsUsed: <String>['Alicate amperímetro', 'Disjuntor bipolar 40 A', 'Fita isolante'],
      beforeAfterPhotoCaptionsOrUrls: <String>[
        'ANTES: Estado inicial #$n',
        'DEPOIS: Execução finalizada #$n',
        'DETALHE: Acabamento técnico #$n',
      ],
      warrantyCertificateCode: 'GAR-GAL-$n',
      isReviewedByClient: reviewed,
      clientRating: reviewed ? 5.0 : null,
      clientReviewComment: reviewed ? 'Serviço #$n impecável, super recomendo!' : null,
      clientPraiseTags: reviewed ? const <String>['Pontual', 'Excelente'] : const <String>[],
      clientDisplayName: _longClientName,
    );

/// Semeia o singleton do portfólio (sem rede) com [n] serviços ricos.
void _seedPortfolio(int n, {int curated = 0}) {
  final store = ProviderPortfolioStore.instance;
  store.resetToCount(0);
  for (var i = 1; i <= n; i++) {
    store.completeAndValidateServiceWithPin(_record(i, reviewed: i != 2));
  }
  for (var i = 1; i <= curated; i++) {
    store.addServiceFromHistoryToPortfolio('srv-$i');
  }
}

// ------------------------------------------------------------- perfil

UserProfile _editProfile() => const UserProfile(
      id: SampleData.providerId,
      fullName: 'João Carlos Ferreira da Silva Junior',
      isClient: true,
      isProvider: true,
      providerSetupDone: true,
      verificationStatus: VerificationStatus.active,
      bio: 'Eletricista residencial há 12 anos, especialista em quadros de distribuição, '
          'iluminação de LED e instalação de ar-condicionado. Atendo toda a região central.',
      addressCity: 'Poços de Caldas - MG',
      phone: '(35) 91234-5678',
    );

Map<String, dynamic> _providerRow() => <String, dynamic>{
      'headline': 'Eletricista residencial · NR-10 · atendimento 24 horas',
      'specialties': <String>['Elétrica', 'Iluminação', 'Ar-condicionado'],
      'hourly_rate': 90.5,
      'visit_fee': 30,
      'service_radius_km': 25,
    };

// ------------------------------------------------------------- core/ui

final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

PickedImage _picked(int i, {String? caption}) => PickedImage(_png1x1, 'png', 'foto_$i.png', caption: caption);

Widget _coreWidgetsShowcase() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Botões', trailing: Text('3 estilos')),
        PrimaryButton(label: 'Confirmar e pagar o profissional com segurança', onPressed: () {}, icon: Icons.lock_rounded),
        const SizedBox(height: 8),
        const PrimaryButton(label: 'Carregando', onPressed: null, loading: true),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Continuar', onPressed: () {}, trailingArrow: true),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Voltar para o painel', onPressed: () {}, icon: Icons.arrow_back_rounded),
        LinkButton(label: 'Ver termos de uso e política de privacidade', onPressed: () {}),
        const SizedBox(height: 12),
        const SectionTitle('Chips e banners'),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip('Concluído e pago', icon: Icons.check_circle_rounded),
            StatusChip('Aguardando aprovação do cliente'),
            StatusChip('Em mediação'),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in BannerTone.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBanner(
              'Mensagem de exemplo com duas ou três linhas para estressar o layout do banner de tipo ${t.name}.',
              tone: t,
              title: 'Título do banner ${t.name}',
            ),
          ),
        const SectionTitle('Cartão, estrelas e etapas'),
        AppCard(
          onTap: () {},
          child: const Text('Cartão tocável com texto longo que precisa quebrar linha sem estourar o limite do cartão em telas estreitas.'),
        ),
        const SizedBox(height: 8),
        RatingStars(value: 4.5, onChanged: (_) {}),
        const SizedBox(height: 8),
        const StepperBar(total: 5, current: 2),
        const SizedBox(height: 8),
        const Center(
          child: CountdownRing(
            remaining: Duration(minutes: 12, seconds: 34),
            total: Duration(minutes: 30),
            size: 160,
            caption: 'para responder',
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(height: 8),
        const Row(children: [BrandLogo(), Spacer(), UserAvatar(name: _longClientName, verified: true)]),
        BellButton(count: 7, onPressed: () {}),
      ],
    );

/// Telas/sheets/widgets do modo profissional (`provider/presentation`).
ProviderDashboardData _dashboardData() {
  final job = SampleData.job(
    status: JobStatus.inProgress,
    title: _longJobTitle,
    price: 1850.5,
    providerId: SampleData.providerId,
    paymentStatus: 'escrow',
  );
  final openJob = SampleData.job(
    id: 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
    status: JobStatus.open,
    title: 'Instalar aquecedor a gás e revisar tubulação',
    category: 'Hidráulica',
    price: 620,
  );
  return ProviderDashboardData(
    jobs: <Job>[job],
    invites: <({JobInvite invite, Job job})>[
      (
        invite: JobInvite(
          jobId: openJob.id,
          providerId: SampleData.providerId,
          status: 'pending',
          expiresAt: DateTime.utc(2099, 1, 15, 12),
          createdAt: DateTime.utc(2026, 10, 1),
        ),
        job: openJob,
      ),
    ],
    quotes: const <({Quote quote, Job? job})>[],
    wallet: const WalletSummary(
      available: 4820.5,
      held: 1850.5,
      week: 3120.0,
      perDay: <double>[420, 680, 0, 540, 890, 590, 0],
    ),
    row: <String, dynamic>{
      'rating_avg': 4.9,
      'rating_count': 127,
      'jobs_done': 342,
      'accepting': true,
      'specialties': <String>['Elétrica', 'Hidráulica'],
    },
  );
}

List<GalleryScreen> providerScreens() => <GalleryScreen>[
      // ------------------------------------------------------ dossiê
      GalleryScreen(
        id: 'provider/dossie_concluido',
        title: 'Dossiê do serviço (concluído, com avaliação)',
        source: 'features/provider/presentation/dossie_servico_profissional_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _dossier(),
      ),
      GalleryScreen(
        id: 'provider/dossie_mediacao',
        title: 'Dossiê do serviço (em mediação, sem avaliação)',
        source: 'features/provider/presentation/dossie_servico_profissional_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _dossier(status: 'disputed', review: false),
      ),
      GalleryScreen(
        id: 'provider/dossie_erro',
        title: 'Dossiê do serviço (erro ao carregar)',
        source: 'features/provider/presentation/dossie_servico_profissional_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => _dossier(fail: true),
      ),
      // ------------------------------------------------------ nota fiscal
      GalleryScreen(
        id: 'provider/material_receipt_inicial',
        title: 'Nota fiscal dos materiais (estado inicial)',
        source: 'features/provider/presentation/material_receipt_capture_screen.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => MaterialReceiptCaptureScreen(
          jobId: 'job-1',
          providerId: SampleData.providerId,
          photoPicker: () async => null,
          clipboardReader: () async => null,
        ),
      ),
      // ------------------------------------------------------ saque Pix
      GalleryScreen(
        id: 'provider/pix_withdraw',
        title: 'Saque via Pix (saldo alto)',
        source: 'features/provider/presentation/pix_withdraw_screen.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const PixWithdrawScreen(available: 123456.78),
      ),
      GalleryScreen(
        id: 'provider/pix_withdraw_disputa',
        title: 'Saque via Pix (disputa aberta / saldo zero)',
        source: 'features/provider/presentation/pix_withdraw_screen.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const PixWithdrawScreen(available: 0, hasOpenDispute: true),
      ),
      // ------------------------------------------------------ execução
      GalleryScreen(
        id: 'provider/warranty_intro',
        title: 'Garantia e portfólio (intro)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => WarrantyIntroScreen(job: _job(JobStatus.inProgress)),
      ),
      GalleryScreen(
        id: 'provider/safety',
        title: 'Garantia e segurança',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => SafetyScreen(job: _job(JobStatus.inProgress)),
      ),
      GalleryScreen(
        id: 'provider/thanks',
        title: 'Obrigado (avaliação enviada)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => const ThanksScreen(),
      ),
      GalleryScreen(
        id: 'provider/thanks_revelada',
        title: 'Obrigado (avaliações reveladas)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => const ThanksScreen(revealed: true),
      ),
      GalleryScreen(
        id: 'provider/paid_success',
        title: 'Pagamento liberado (sucesso)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => PaidSuccessScreen(job: _job(JobStatus.completed, price: 12345.67, payment: 'released')),
      ),
      GalleryScreen(
        id: 'provider/evidence_checklist',
        title: 'Checklist de evidências',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => EvidenceChecklistScreen(job: _job(JobStatus.inProgress)),
      ),
      GalleryScreen(
        id: 'provider/release_payment',
        title: 'Liberar pagamento (PIN do cliente)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ReleasePaymentScreen(job: _job(JobStatus.awaitingApproval)),
      ),
      GalleryScreen(
        id: 'provider/mediation',
        title: 'Mediação em andamento',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => MediationScreen(job: _job(JobStatus.disputed)),
      ),
      GalleryScreen(
        id: 'provider/rate_client',
        title: 'Avaliar o cliente',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => RateClientScreen(job: _job(JobStatus.completed, payment: 'released')),
      ),
      // ------------------------------------------------------ orçamento / convite
      GalleryScreen(
        id: 'provider/client_card_tile',
        title: 'Cartão do cliente (sem dados: rede indisponível)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const Padding(padding: EdgeInsets.all(16), child: ClientCardTile(jobId: 'j1')),
      ),
      GalleryScreen(
        id: 'provider/quote_form',
        title: 'Enviar orçamento (pedido aberto)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => QuoteFormScreen(job: _job(JobStatus.open, price: 0)),
      ),
      GalleryScreen(
        id: 'provider/quote_form_convite',
        title: 'Enviar orçamento (com convite e contagem regressiva)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => QuoteFormScreen(
          job: _job(JobStatus.open, price: 0),
          invite: JobInvite(
            jobId: 'j1',
            providerId: SampleData.providerId,
            status: 'pending',
            expiresAt: DateTime.now().add(const Duration(minutes: 12, seconds: 34)),
            createdAt: DateTime.now(),
          ),
        ),
      ),
      GalleryScreen(
        id: 'provider/awaiting_response',
        title: 'Aguardando resposta do cliente',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => AwaitingResponseScreen(
          job: _job(JobStatus.open, price: 0),
          quote: Quote(
            id: 'q1',
            jobId: 'j1',
            providerId: SampleData.providerId,
            price: 12345.67,
            status: 'pending',
            createdAt: DateTime.now(),
            message: 'Posso começar amanhã cedo; materiais inclusos no valor combinado, garantia de 90 dias no serviço.',
            estimatedHours: 3.5,
          ),
        ),
      ),
      GalleryScreen(
        id: 'provider/emergency_decision',
        title: 'Decisão de urgência (convite SOS)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => EmergencyDecisionScreen(
          job: SampleData.job(
            status: JobStatus.open,
            title: _longJobTitle,
            urgency: 'emergency',
            category: 'Chaveiro',
          ),
          invite: JobInvite(
            jobId: 'j1',
            providerId: SampleData.providerId,
            status: 'pending',
            expiresAt: DateTime.now().add(const Duration(seconds: 45)),
            createdAt: DateTime.now(),
          ),
        ),
      ),
      // ------------------------------------------------------ portfólio
      GalleryScreen(
        id: 'provider/portfolio_secao_dono',
        title: 'Portfólio inteligente (visão do dono, 6 serviços)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) {
          _seedPortfolio(6, curated: 2);
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(isOwner: true, syncOnMount: false),
          );
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_secao_cliente',
        title: 'Portfólio inteligente (visão do cliente, preços ocultos)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) {
          _seedPortfolio(6, curated: 2);
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(isOwner: false, syncOnMount: false),
          );
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_secao_vazia',
        title: 'Portfólio inteligente (vazio)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) {
          _seedPortfolio(0);
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(isOwner: true, syncOnMount: false),
          );
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_historico',
        title: 'Histórico completo de serviços',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) {
          _seedPortfolio(6, curated: 2);
          return const ProviderFullHistoryScreen(syncOnMount: false);
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_historico_vazio',
        title: 'Histórico completo de serviços (vazio)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) {
          _seedPortfolio(0);
          return const ProviderFullHistoryScreen(syncOnMount: false);
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_card',
        title: 'Card de serviço concluído (destaque, nome longo)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: CompletedServicePortfolioCard(
            service: _record(1),
            positionBadge: '#1 Top 3',
            isAutomaticTopThree: true,
            onTap: () {},
            onSwapFromHistory: () {},
            onRemoveFromPortfolio: () {},
          ),
        ),
      ),
      GalleryScreen(
        id: 'provider/portfolio_detalhe_sheet',
        title: 'Detalhe do serviço no portfólio (sheet, dono)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.sheet,
        rawSheet: true,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) {
          _seedPortfolio(4, curated: 1);
          return const FractionallySizedBox(
            heightFactor: 0.90,
            child: PortfolioServiceDetailSheet(serviceId: 'srv-1', isOwner: true),
          );
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_detalhe_sheet_cliente',
        title: 'Detalhe do serviço no portfólio (sheet, cliente)',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.sheet,
        rawSheet: true,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, _) {
          _seedPortfolio(4, curated: 1);
          return const FractionallySizedBox(
            heightFactor: 0.90,
            child: PortfolioServiceDetailSheet(serviceId: 'srv-1', isOwner: false),
          );
        },
      ),
      GalleryScreen(
        id: 'provider/portfolio_foto_tela_cheia',
        title: 'Visualizador de fotos em tela cheia',
        source: 'features/provider/presentation/provider_portfolio_widgets.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const PortfolioFullScreenPhotoViewer(
          photos: <String>['a/foto1.jpg', 'a/foto2.jpg', 'a/foto3.jpg'],
          initialIndex: 0,
          serviceTitle: _longJobTitle,
        ),
      ),
      // ------------------------------------------------------ perfil
      GalleryScreen(
        id: 'provider/edit_profile',
        title: 'Editar perfil profissional (dados completos)',
        source: 'features/provider/presentation/provider_profile_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => EditProviderProfileScreen(
          initialProfileOverride: _editProfile(),
          initialProviderRowOverride: _providerRow(),
        ),
      ),
      GalleryScreen(
        id: 'provider/edit_profile_setup',
        title: 'Editar perfil profissional (cadastro inicial, vazio)',
        source: 'features/provider/presentation/provider_profile_screens.dart',
        wave: 2,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => EditProviderProfileScreen(
          setupMode: true,
          onDone: () {},
          initialProfileOverride: SampleData.firstAccessProfile(),
          initialProviderRowOverride: const <String, dynamic>{},
        ),
      ),
      GalleryScreen(
        id: 'provider/portfolio_fotos',
        title: 'Fotos do portfólio (rede indisponível)',
        source: 'features/provider/presentation/provider_profile_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const PortfolioScreen(),
      ),
      GalleryScreen(
        id: 'provider/certificados',
        title: 'Certificados (rede indisponível)',
        source: 'features/provider/presentation/provider_profile_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const CertificatesScreen(),
      ),
      GalleryScreen(
        id: 'provider/minhas_avaliacoes',
        title: 'Minhas avaliações (rede indisponível)',
        source: 'features/provider/presentation/provider_profile_screens.dart',
        wave: 3,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => MyReviewsScreen(profile: SampleData.providerProfile()),
      ),
      GalleryScreen(
        id: 'provider/setup_flow',
        title: 'Cadastro do profissional (passo 1)',
        source: 'features/provider/presentation/provider_setup_screens.dart',
        wave: 4,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ProviderSetupFlow(profile: SampleData.providerProfile()),
      ),
      // ------------------------------------------------------ casca e abas
      GalleryScreen(
        id: 'provider/opportunities_tab',
        title: 'Oportunidades (rede indisponível)',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 4,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => const OpportunitiesTab(),
      ),
      GalleryScreen(
        id: 'provider/profile_tab',
        title: 'Aba Perfil do profissional',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 4,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ProviderProfileTab(profile: SampleData.providerProfile()),
      ),
      GalleryScreen(
        id: 'provider/earnings_simulator_sheet',
        title: 'Simulador de ganhos (sheet)',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 2,
        owner: 'provider_ui',
        kind: GalleryKind.sheet,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const EarningsSimulatorSheet(),
      ),
      GalleryScreen(
        id: 'provider/weekly_goal_dialog',
        title: 'Meta semanal (diálogo)',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 2,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => const WeeklyGoalDialog(initial: 12500),
      ),
      // ----------------------------------------- ganchos §5.1 (Onda 4)
      GalleryScreen(
        id: 'provider/dashboard_tab',
        title: 'Painel do profissional (com dados)',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 4,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => ProviderDashboardTab(
          profile: SampleData.providerProfile(),
          onSeeOpportunities: () {},
          onSeeWallet: () {},
          loader: () async => _dashboardData(),
        ),
      ),
      GalleryScreen(
        id: 'provider/shell',
        title: 'Casca do profissional (4 abas)',
        source: 'features/provider/presentation/provider_shell.dart',
        wave: 4,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => ProviderShell(
          profile: SampleData.providerProfile(),
          dashboardLoader: () async => _dashboardData(),
          walletLoader: () async => _walletFull(),
        ),
      ),
      GalleryScreen(
        id: 'provider/service_execution',
        title: 'Execução do serviço (profissional)',
        source: 'features/provider/presentation/provider_execution_screens.dart',
        wave: 4,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        animatesForever: true,
        builder: (_, _) => ServiceExecutionScreen(
          job: SampleData.job(
            status: JobStatus.inProgress,
            title: _longJobTitle,
            price: 1850.5,
            providerId: SampleData.providerId,
            paymentStatus: 'escrow',
          ),
          myId: SampleData.providerId,
        ),
      ),
      GalleryScreen(
        id: 'provider/job_aguardando_pagamento',
        title: 'Pedido do profissional (aguardando pagamento)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 4,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ProviderJobScreen(
          jobId: 'j1',
          currentUserId: SampleData.providerId,
          stream: Stream<Job?>.value(
            SampleData.job(
              status: JobStatus.awaitingPayment,
              title: _longJobTitle,
              price: 1850.5,
              providerId: SampleData.providerId,
            ),
          ),
        ),
      ),
      GalleryScreen(
        id: 'provider/job_indisponivel',
        title: 'Pedido do profissional (indisponível/cancelado)',
        source: 'features/provider/presentation/provider_job_screen.dart',
        wave: 4,
        owner: 'provider_ui',
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => ProviderJobScreen(
          jobId: 'j1',
          currentUserId: SampleData.providerId,
          stream: Stream<Job?>.value(
            SampleData.job(
              status: JobStatus.canceled,
              title: _longJobTitle,
            ),
          ),
        ),
      ),
      // ------------------------------------------------------ carteira
      GalleryScreen(
        id: 'provider/wallet_cheia',
        title: 'Carteira do profissional (valores altos, nomes longos)',
        source: 'features/provider/presentation/wallet_tab.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => WalletTab(loader: () async => _walletFull()),
      ),
      GalleryScreen(
        id: 'provider/wallet_vazia',
        title: 'Carteira do profissional (sem recebimentos)',
        source: 'features/provider/presentation/wallet_tab.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => WalletTab(loader: () async => (<Payment>[], <String, Job>{}, 0.0)),
      ),
      GalleryScreen(
        id: 'provider/wallet_erro',
        title: 'Carteira do profissional (erro ao carregar)',
        source: 'features/provider/presentation/wallet_tab.dart',
        wave: 3,
        owner: 'provider_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.provider},
        builder: (_, _) => WalletTab(loader: () async => throw StateError('falha simulada')),
      ),
    ];

/// Núcleo `core/ui` (widgets, mídia, seleção de fotos, scaffold).
List<GalleryScreen> coreUiScreens() => <GalleryScreen>[
      GalleryScreen(
        id: 'core/widgets_showcase',
        title: 'Componentes de core/ui/widgets.dart (botões, chips, banners, cartão, estrelas)',
        source: 'core/ui/widgets.dart',
        wave: 1,
        owner: 'shared_ui',
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => AppScaffold(
          appBar: AppBar(title: const Text('Componentes')),
          body: _coreWidgetsShowcase(),
        ),
      ),
      GalleryScreen(
        id: 'core/widgets_estados',
        title: 'LoadingView / ErrorView / EmptyView',
        source: 'core/ui/widgets.dart',
        wave: 1,
        owner: 'shared_ui',
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        animatesForever: true,
        builder: (_, _) => AppScaffold(
          appBar: AppBar(title: const Text('Estados')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingView(message: 'Carregando seus dados com segurança...'),
              ),
              const Divider(),
              ErrorView(
                message: 'Não foi possível carregar as informações do serviço. Verifique sua conexão e tente novamente.',
                onRetry: () {},
              ),
              const Divider(),
              EmptyView(
                icon: Icons.inbox_rounded,
                title: 'Nenhum serviço por aqui ainda',
                subtitle: 'Quando você concluir um serviço ele aparece aqui com todos os detalhes e garantias.',
                action: PrimaryButton(label: 'Ver oportunidades', onPressed: () {}),
              ),
            ],
          ),
        ),
      ),
      GalleryScreen(
        id: 'core/pulse_radar',
        title: 'PulseRadar (animação em loop)',
        source: 'core/ui/widgets.dart',
        wave: 1,
        owner: 'shared_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        animatesForever: true,
        builder: (_, _) => const Center(child: PulseRadar(child: Icon(Icons.bolt_rounded, size: 48))),
      ),
      GalleryScreen(
        id: 'core/media_imagens',
        title: 'InstantCachedImage / SignedImage / PublicImage / InstantUserAvatar (sem rede)',
        source: 'core/ui/media_widgets.dart',
        wave: 1,
        owner: 'shared_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              InstantCachedImage(width: 96, height: 96),
              InstantCachedImage(
                width: 96,
                height: 96,
                url: 'https://exemplo.invalid/foto.jpg',
                placeholder: ColoredBox(color: Colors.black12),
                errorWidget: Icon(Icons.broken_image_rounded),
              ),
              SignedImage(path: 'job-photos/abc/foto.jpg', width: 96, height: 96),
              PublicImage(path: 'portfolio/abc/foto.jpg', width: 96, height: 96),
              InstantUserAvatar(name: _longClientName, radius: 32, verified: true),
              InstantUserAvatar(name: 'Ana', radius: 24),
              InstantUserAvatar(name: 'João Carlos', radius: 28, isSquircle: true),
            ],
          ),
        ),
      ),
      GalleryScreen(
        id: 'core/media_picker_row',
        title: 'MediaPickerRow (3 fotos de 4)',
        source: 'core/ui/image_picking.dart',
        wave: 2,
        owner: 'shared_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: MediaPickerRow(
            images: <PickedImage>[_picked(1, caption: 'Quadro de luz aberto'), _picked(2), _picked(3, caption: 'Fio derretido perto do disjuntor')],
            onAdd: () {},
            onRemove: (_) {},
            onEdit: (_) {},
          ),
        ),
      ),
      GalleryScreen(
        id: 'core/media_picker_row_vazio',
        title: 'MediaPickerRow (vazio)',
        source: 'core/ui/image_picking.dart',
        wave: 2,
        owner: 'shared_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: MediaPickerRow(images: const <PickedImage>[], onAdd: () {}, onRemove: (_) {}),
        ),
      ),
      GalleryScreen(
        id: 'core/photo_context_studio_sheet',
        title: 'Estúdio de contexto da foto (sheet)',
        source: 'core/ui/image_picking.dart',
        wave: 2,
        owner: 'shared_ui',
        kind: GalleryKind.sheet,
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => PhotoContextStudioSheet(image: _picked(1), photoIndex: 0, categoryName: 'Elétrica'),
      ),
      GalleryScreen(
        id: 'core/app_scaffold',
        title: 'AppScaffold (barra inferior + FAB)',
        source: 'core/ui/app_scaffold.dart',
        wave: 0,
        owner: 'shared_ui',
        modes: const <UserMode?>{UserMode.client, UserMode.provider},
        builder: (_, _) => AppScaffold(
          appBar: AppBar(title: const Text('AppScaffold')),
          body: const Center(child: Text('Corpo da tela')),
          floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
          bottomNavigationBar: BottomBar(
            footnote: 'Pagamento protegido pela plataforma até a sua confirmação.',
            child: PrimaryButton(label: 'Confirmar', onPressed: () {}),
          ),
        ),
      ),
    ];
