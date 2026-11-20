import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/models/wallet_models.dart';
import 'package:desperrengue_app/core/services/speech_service.dart';
import 'package:desperrengue_app/core/services/text_refine_service.dart';
import 'package:desperrengue_app/core/ui/image_picking.dart';
import 'package:desperrengue_app/features/client/presentation/address_form.dart';
import 'package:desperrengue_app/features/client/presentation/adicionar_saldo_screen.dart';
import 'package:desperrengue_app/features/client/presentation/carteira_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/category_picker.dart';
import 'package:desperrengue_app/features/client/presentation/client_job_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_shell.dart';
import 'package:desperrengue_app/features/client/presentation/completion_screens.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/historico_servicos_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/order_tracking_screen.dart';
import 'package:desperrengue_app/features/client/presentation/payment_widgets.dart';
import 'package:desperrengue_app/features/client/presentation/provider_public_profile_screen.dart';
import 'package:desperrengue_app/features/client/presentation/provider_search_screen.dart';
import 'package:desperrengue_app/features/client/presentation/published_overlay.dart';
import 'package:desperrengue_app/features/client/presentation/request_wizard.dart';
import 'package:desperrengue_app/features/client/presentation/voice_dictation.dart';
import 'package:desperrengue_app/features/client/presentation/wallet_chip.dart';
import 'package:flutter/material.dart';

import '../../support/screen_gallery/screen_gallery.dart';

// REGISTRO DA GALERIA — GRUPO B (features/client/presentation/**).
//
// NÃO registradas (e por quê):
//  * ClientJobScreen (client_job_screen.dart:35) — streamJob realtime sem injeção
//    nunca emite no Supabase fake (permanece em CircularProgressIndicator sem RichText);
//    precisa de parâmetro `jobStream`.
//  * EmergencyRadarScreen (client_job_screen.dart:1493) — initState consulta Supabase
//    sem catch/injeção (lança PostgrestException 400); precisa de loader injetável.
//  * DocumentGuidedScannerModal (client_setup_screen.dart:1918) — inicializa
//    CameraController/availableCameras() em initState sem factory injetável.
//  * Telas já registradas em `seed_screens.dart` (não duplicadas aqui):
//    `client/carteira`, `client/category_grid`, `client/insufficient_funds_sheet`.
//  * Privadas (`_MatchDialog`, `_CanceledView`, `_PixView`, `_AmountView`, …) e
//    sub-widgets puros internos (`EntryTile`, `CategoryTile`, `RadiusSlider`,
//    `AreaPublishButton`, `OrderPublishStepper`, `LiveSearchRadarHeader`,
//    `SoundWaveBars`, `OrdersTabs`) já renderizados dentro das telas acima.

const String _core = 'client_core_ui';
const String _orders = 'client_orders_ui';
const String _shared = 'shared_ui';
const Set<UserMode?> _client = <UserMode?>{UserMode.client};
const String _dir = 'features/client/presentation';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

// ------------------------------------------------------------------- fakes

class _NoGeo implements AddressGeocoder {
  const _NoGeo();
  @override
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep}) async => null;
}

class _FakeSpeech implements SpeechEngine {
  bool _listening = false;
  @override
  bool get isListening => _listening;
  @override
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError}) async => true;
  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  }) async {
    _listening = true;
  }

  @override
  Future<void> stop() async => _listening = false;
}

class _NoRefine implements TextRefiner {
  const _NoRefine();
  @override
  Future<String> refine(String text) async => text;
}

// ------------------------------------------------------------------- dados

const String _longTitle = 'Reforma completa da instalação elétrica do apartamento com troca de quadro e fiação';

UserProfile _profile() => UserProfile(
  id: 'me',
  fullName: 'Ana Paula Souza',
  isClient: true,
  clientSetupDone: true,
  phone: '(11) 98765-4321',
  addressLine: 'Rua das Acácias, 123 - Apto 45, Jardim América, São Paulo - SP',
  addressCity: 'São Paulo - SP',
  latitude: -23.56,
  longitude: -46.66,
);

Job _job(
  JobStatus s, {
  String id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  String title = 'Trocar disjuntor e revisar quadro de luz',
  double? price,
  String? providerId,
  String payment = 'pending',
  int quotes = 0,
}) => Job(
  id: id,
  clientId: 'me',
  title: title,
  description:
      'O disjuntor desarma toda vez que ligo o chuveiro e o forno ao mesmo tempo. '
      'Preciso de alguém para revisar o quadro de luz com segurança.',
  category: 'Elétrica',
  status: s,
  paymentStatus: payment,
  urgency: 'scheduled',
  visibility: 'open',
  createdAt: DateTime(2026, 10, 1, 14, 30),
  providerId: providerId,
  agreedPrice: price,
  budgetEstimate: price,
  addressSummary: 'Jardim América, São Paulo - SP',
  quoteCount: quotes,
  scheduledFor: DateTime(2026, 10, 12, 9, 0),
);

List<Job> _mixedJobs() => <Job>[
  _job(JobStatus.open, id: 'j-open-0000-0000-0000-000000000001', quotes: 3),
  _job(
    JobStatus.scheduled,
    id: 'j-sche-0000-0000-0000-000000000002',
    price: 1250.9,
    providerId: 'prov-1',
    title: _longTitle,
  ),
  _job(JobStatus.inProgress, id: 'j-prog-0000-0000-0000-000000000003', price: 180, providerId: 'prov-1'),
  _job(JobStatus.awaitingApproval, id: 'j-appr-0000-0000-0000-000000000004', price: 4300, providerId: 'prov-2'),
  _job(
    JobStatus.completed,
    id: 'j-done-0000-0000-0000-000000000005',
    price: 180.5,
    providerId: 'prov-1',
    payment: 'released',
  ),
  _job(JobStatus.canceled, id: 'j-canc-0000-0000-0000-000000000006'),
  _job(
    JobStatus.disputed,
    id: 'j-disp-0000-0000-0000-000000000007',
    price: 800,
    providerId: 'prov-2',
    payment: 'escrow',
  ),
];

Quote _quote(int i, double price, {String? message}) => Quote(
  id: 'q$i',
  jobId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  providerId: 'prov-$i',
  price: price,
  status: 'pending',
  createdAt: DateTime(2026, 10, 1, 15, 0),
  message: message,
  estimatedHours: 3,
);

Map<String, dynamic> _dossier({
  String status = 'completed',
  String title = 'Trocar chuveiro e revisar a fiação do banheiro',
  bool review = true,
}) => <String, dynamic>{
  'job_id': '1a2b3c4d-0000-0000-0000-000000000000',
  'code': '#DESP-1A2B3',
  'title': title,
  'description':
      'O chuveiro queimou e preciso trocar por um novo. Aproveitar para revisar a fiação, '
      'que está esquentando perto do disjuntor.',
  'category': 'Elétrica',
  'status': status,
  'scheduled_for': '2026-10-20T13:00:00Z',
  'started_at': '2026-10-20T13:05:00Z',
  'finished_at': status == 'completed' ? '2026-10-20T14:30:00Z' : null,
  'address_summary': 'Jardim América, São Paulo - SP',
  'photo_paths': <String>['u/pedido1.jpg'],
  'amount': 1850.5,
  'payment_status': status == 'completed' ? 'released' : 'escrow',
  'provider': <String, dynamic>{
    'id': 'prov-1',
    'name': 'Carlos Eduardo Silva de Albuquerque',
    'avatar_url': null,
    'title': 'Eletricista residencial · NR-10',
    'rating_avg': 4.8,
    'rating_count': 127,
  },
  'evidence': status == 'completed'
      ? <Map<String, dynamic>>[
          <String, dynamic>{'slot': 'clean', 'path': 'u/clean.jpg'},
          <String, dynamic>{'slot': 'overview', 'path': 'u/overview.jpg'},
          <String, dynamic>{'slot': 'detail', 'path': 'u/detail.jpg'},
        ]
      : <Map<String, dynamic>>[],
  'report': status == 'completed' ? 'Troquei o chuveiro, testei a fiação e reapertei os terminais do disjuntor.' : null,
  'my_review': review && status == 'completed'
      ? <String, dynamic>{
          'rating': 5,
          'tags': <String>['Pontual', 'Educado'],
          'comment': 'Excelente trabalho, muito cuidadoso e explicou tudo o que fez.',
          'created_at': '2026-10-20T15:00:00Z',
        }
      : null,
};

Widget _evidence(BuildContext c, String path, BoxFit fit) =>
    ColoredBox(color: Theme.of(c).colorScheme.surfaceContainerHighest);

// --------------------------------------------------------------- registro

List<GalleryScreen> clientScreens() => <GalleryScreen>[
  // ------------------------------------------------------------ onda 2
  GalleryScreen(
    id: 'client/address_form',
    title: 'Formulário de endereço (preenchido)',
    source: '$_dir/address_form.dart',
    wave: 2,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AddressForm(
        onChanged: (_) {},
        geocoder: const _NoGeo(),
        initial: const AddressData(
          cep: '01452-000',
          street: 'Avenida Brigadeiro Faria Lima',
          number: '1234',
          complement: 'Conjunto 56 - Bloco B',
          neighborhood: 'Jardim Paulistano',
          city: 'São Paulo',
          uf: 'SP',
        ),
      ),
    ),
  ),
  GalleryScreen(
    id: 'client/address_form_vazio',
    title: 'Formulário de endereço (vazio)',
    source: '$_dir/address_form.dart',
    wave: 2,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AddressForm(onChanged: (_) {}, geocoder: const _NoGeo()),
    ),
  ),
  GalleryScreen(
    id: 'client/category_grid_completa',
    title: 'Grade de categorias (todas)',
    source: '$_dir/category_picker.dart',
    wave: 2,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CategoryGrid(onPick: (_) {}, count: 99),
    ),
  ),
  GalleryScreen(
    id: 'client/provider_search',
    title: 'Busca de profissionais (lista)',
    source: '$_dir/provider_search_screen.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => ProviderSearchScreen(
      category: 'Elétrica',
      profile: _profile(),
      loader: ({String? category, String? query, required bool includeSelf}) async => <ProviderCard>[
        SampleData.providerCard(name: 'Carlos Eduardo Silva de Albuquerque', i: 1),
        SampleData.providerCard(name: 'Maria Fernanda Nascimento', i: 2),
        SampleData.providerCard(name: 'João', i: 3),
      ],
    ),
  ),
  GalleryScreen(
    id: 'client/provider_search_vazio',
    title: 'Busca de profissionais (sem resultados)',
    source: '$_dir/provider_search_screen.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => ProviderSearchScreen(
      category: 'Impermeabilização',
      profile: _profile(),
      loader: ({String? category, String? query, required bool includeSelf}) async => <ProviderCard>[],
    ),
  ),
  GalleryScreen(
    id: 'client/provider_search_erro',
    title: 'Busca de profissionais (erro)',
    source: '$_dir/provider_search_screen.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => ProviderSearchScreen(
      category: 'Elétrica',
      profile: _profile(),
      loader: ({String? category, String? query, required bool includeSelf}) async =>
          throw StateError('falha simulada'),
    ),
  ),
  GalleryScreen(
    id: 'client/request_wizard_0',
    title: 'Novo pedido — passo 1',
    source: '$_dir/request_wizard.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => RequestWizardScreen(
      profile: _profile(),
      speechEngine: _FakeSpeech(),
      textRefiner: const _NoRefine(),
      openRequestsCounter: () async => 0,
    ),
  ),
  GalleryScreen(
    id: 'client/request_wizard_1',
    title: 'Novo pedido — passo 2 (descrição e foto)',
    source: '$_dir/request_wizard.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => RequestWizardScreen(
      profile: _profile(),
      category: 'Elétrica',
      speechEngine: _FakeSpeech(),
      textRefiner: const _NoRefine(),
      openRequestsCounter: () async => 0,
      debugStep: 1,
      debugDescription:
          'O disjuntor desarma toda vez que ligo o chuveiro e o forno ao mesmo tempo. '
          'Preciso de alguém para revisar o quadro de luz com segurança.',
      debugImages: <PickedImage>[PickedImage(_png, 'png', 'a.png')],
    ),
  ),
  GalleryScreen(
    id: 'client/request_wizard_2',
    title: 'Novo pedido — passo 3 (revisão)',
    source: '$_dir/request_wizard.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    builder: (_, _) => RequestWizardScreen(
      profile: _profile(),
      category: 'Elétrica',
      speechEngine: _FakeSpeech(),
      textRefiner: const _NoRefine(),
      openRequestsCounter: () async => 0,
      debugStep: 2,
      debugDescription: 'Cheiro de queimado no quadro de luz.',
      debugImages: <PickedImage>[PickedImage(_png, 'png', 'a.png')],
    ),
  ),
  GalleryScreen(
    id: 'client/voice_dictation_panel',
    title: 'Painel de ditado por voz',
    source: '$_dir/voice_dictation.dart',
    wave: 2,
    owner: _shared,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: VoiceDictationPanel(
        textController: TextEditingController(text: 'O disjuntor desarma quando ligo o chuveiro.'),
        engine: _FakeSpeech(),
        refiner: const _NoRefine(),
      ),
    ),
  ),
  GalleryScreen(
    id: 'client/published_overlay',
    title: 'Pedido publicado (animação)',
    source: '$_dir/published_overlay.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => const PublishedOrderOverlay(categoryName: 'Impermeabilização e reformas'),
  ),
  GalleryScreen(
    id: 'client/published_overlay_direto',
    title: 'Pedido publicado (direto ao profissional)',
    source: '$_dir/published_overlay.dart',
    wave: 2,
    owner: _orders,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => const PublishedOrderOverlay(
      categoryName: 'Elétrica',
      direct: true,
      providerName: 'Carlos Eduardo Silva de Albuquerque',
    ),
  ),

  // ------------------------------------------------------------ onda 3
  GalleryScreen(
    id: 'client/adicionar_saldo',
    title: 'Adicionar saldo (valor sugerido)',
    source: '$_dir/adicionar_saldo_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => const AdicionarSaldoScreen(suggestedCents: 2250000),
  ),
  GalleryScreen(
    id: 'client/adicionar_saldo_vazio',
    title: 'Adicionar saldo (sem sugestão)',
    source: '$_dir/adicionar_saldo_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => const AdicionarSaldoScreen(),
  ),
  GalleryScreen(
    id: 'client/carteira_vazia',
    title: 'Carteira (sem movimentações)',
    source: '$_dir/carteira_cliente_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    overrides: (_) => walletOverrides(
      service: FakeWalletService(wallet: SampleData.wallet(available: 0, escrow: 0), statement: const <WalletEntry>[]),
    ),
    builder: (_, _) => const CarteiraClienteScreen(),
  ),
  GalleryScreen(
    id: 'client/carteira_erro',
    title: 'Carteira (erro ao carregar)',
    source: '$_dir/carteira_cliente_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    overrides: (_) => walletOverrides(service: FakeWalletService(walletError: StateError('falha simulada'))),
    builder: (_, _) => const CarteiraClienteScreen(),
  ),
  GalleryScreen(
    id: 'client/carteira_valor_alto',
    title: 'Carteira (valores altos)',
    source: '$_dir/carteira_cliente_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    overrides: (_) =>
        walletOverrides(service: FakeWalletService(wallet: SampleData.wallet(available: 987654321, escrow: 123456789))),
    builder: (_, _) => const CarteiraClienteScreen(),
  ),
  GalleryScreen(
    id: 'client/wallet_pay_card',
    title: 'Cartão de pagamento por saldo (suficiente)',
    source: '$_dir/payment_widgets.dart',
    wave: 3,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => const Padding(padding: EdgeInsets.all(16), child: WalletPayCard(priceCents: 45000)),
  ),
  GalleryScreen(
    id: 'client/wallet_pay_card_insuficiente',
    title: 'Cartão de pagamento por saldo (insuficiente)',
    source: '$_dir/payment_widgets.dart',
    wave: 3,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => const Padding(padding: EdgeInsets.all(16), child: WalletPayCard(priceCents: 99999900)),
  ),
  GalleryScreen(
    id: 'client/wallet_chip',
    title: 'Chip de saldo',
    source: '$_dir/wallet_chip.dart',
    wave: 3,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => const Padding(
      padding: EdgeInsets.all(16),
      child: Align(alignment: Alignment.centerRight, child: WalletChip()),
    ),
  ),
  GalleryScreen(
    id: 'client/orders_tab_cheia',
    title: 'Meus pedidos (todas as situações)',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _orders,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => ClientOrdersTab(
      jobsStream: Stream<List<Job>>.value(_mixedJobs()),
      onOpen: (_, _) {},
      includeMediationTab: true,
    ),
  ),
  GalleryScreen(
    id: 'client/orders_tab_vazia',
    title: 'Meus pedidos (vazio)',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _orders,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => ClientOrdersTab(jobsStream: Stream<List<Job>>.value(const <Job>[]), onOpen: (_, _) {}),
  ),
  GalleryScreen(
    id: 'client/orders_tab_erro',
    title: 'Meus pedidos (erro)',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _orders,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) =>
        ClientOrdersTab(jobsStream: Stream<List<Job>>.error(StateError('falha simulada')), onOpen: (_, _) {}),
  ),
  GalleryScreen(
    id: 'client/orders_tab_carregando',
    title: 'Meus pedidos (carregando)',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _orders,
    kind: GalleryKind.widget,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => ClientOrdersTab(jobsStream: StreamController<List<Job>>().stream, onOpen: (_, _) {}),
  ),
  GalleryScreen(
    id: 'client/profile_tab',
    title: 'Perfil do cliente',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => ClientProfileTab(profile: _profile()),
  ),
  GalleryScreen(
    id: 'client/profile_tab_nome_longo',
    title: 'Perfil do cliente (nome longo)',
    source: '$_dir/client_orders_tab.dart',
    wave: 3,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    builder: (_, _) => ClientProfileTab(
      profile: UserProfile(
        id: 'me',
        fullName: SampleData.longName,
        isClient: true,
        isProvider: true,
        clientSetupDone: true,
        providerSetupDone: true,
        phone: '(11) 98765-4321',
      ),
    ),
  ),
  GalleryScreen(
    id: 'client/edit_address',
    title: 'Editar endereço',
    source: '$_dir/client_setup_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    builder: (_, _) =>
        const EditAddressScreen(currentLine: 'Rua das Acácias, 123 - Apto 45, Jardim América, São Paulo - SP'),
  ),
  GalleryScreen(
    id: 'client/setup_0',
    title: 'Cadastro do cliente — passo 1',
    source: '$_dir/client_setup_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    builder: (_, _) => ClientSetupScreen(profile: SampleData.firstAccessProfile()),
  ),
  GalleryScreen(
    id: 'client/setup_1',
    title: 'Cadastro do cliente — passo 2',
    source: '$_dir/client_setup_screen.dart',
    wave: 3,
    owner: _core,
    modes: _client,
    builder: (_, _) => ClientSetupScreen(profile: SampleData.firstAccessProfile(), initialStep: 1),
  ),
  GalleryScreen(
    id: 'client/historico',
    title: 'Histórico de serviços',
    source: '$_dir/historico_servicos_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => HistoricoServicosClienteScreen(
      loader: () async => <Job>[
        _job(JobStatus.completed, id: 'h1000000-0000-4000-8000-000000000001', price: 1850.5, providerId: 'prov-1', title: _longTitle),
        _job(JobStatus.completed, id: 'h2000000-0000-4000-8000-000000000002', price: 180, providerId: 'prov-2'),
        _job(JobStatus.canceled, id: 'h3000000-0000-4000-8000-000000000003'),
      ],
    ),
  ),
  GalleryScreen(
    id: 'client/historico_vazio',
    title: 'Histórico de serviços (vazio)',
    source: '$_dir/historico_servicos_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => HistoricoServicosClienteScreen(loader: () async => <Job>[]),
  ),
  GalleryScreen(
    id: 'client/historico_erro',
    title: 'Histórico de serviços (erro)',
    source: '$_dir/historico_servicos_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => HistoricoServicosClienteScreen(loader: () async => throw StateError('falha simulada')),
  ),
  GalleryScreen(
    id: 'client/detalhe_servico_concluido',
    title: 'Detalhe do serviço (concluído e avaliado)',
    source: '$_dir/detalhe_servico_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => DetalheServicoClienteScreen(
      jobId: 'j1',
      dossierLoader: (_) async => ClientDossier.fromMap(_dossier()),
      quotesLoader: (_) async => const <DetailQuote>[],
      imageBuilder: _evidence,
    ),
  ),
  GalleryScreen(
    id: 'client/detalhe_servico_orcamentos',
    title: 'Detalhe do serviço (aguardando orçamento)',
    source: '$_dir/detalhe_servico_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => DetalheServicoClienteScreen(
      jobId: 'j1',
      dossierLoader: (_) async => ClientDossier.fromMap(_dossier(status: 'open', title: _longTitle)),
      quotesLoader: (_) async => const <DetailQuote>[
        DetailQuote(
          providerName: 'Carlos Eduardo Silva de Albuquerque',
          price: 1850.5,
          message: 'Posso ir amanhã às 9h e levo todo o material necessário.',
        ),
        DetailQuote(providerName: 'Maria Fernanda', price: 990),
      ],
      imageBuilder: _evidence,
    ),
  ),
  GalleryScreen(
    id: 'client/detalhe_servico_andamento',
    title: 'Detalhe do serviço (em execução)',
    source: '$_dir/detalhe_servico_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => DetalheServicoClienteScreen(
      jobId: 'j1',
      dossierLoader: (_) async => ClientDossier.fromMap(_dossier(status: 'in_progress')),
      quotesLoader: (_) async => const <DetailQuote>[],
      imageBuilder: _evidence,
    ),
  ),
  GalleryScreen(
    id: 'client/detalhe_servico_vazio',
    title: 'Detalhe do serviço (não encontrado)',
    source: '$_dir/detalhe_servico_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => DetalheServicoClienteScreen(jobId: 'j1', dossierLoader: (_) async => null),
  ),
  GalleryScreen(
    id: 'client/detalhe_servico_erro',
    title: 'Detalhe do serviço (erro)',
    source: '$_dir/detalhe_servico_cliente_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) =>
        DetalheServicoClienteScreen(jobId: 'j1', dossierLoader: (_) async => throw StateError('falha simulada')),
  ),
  GalleryScreen(
    id: 'client/order_tracking',
    title: 'Acompanhamento do pedido',
    source: '$_dir/order_tracking_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => OrderTrackingScreen(
      job: _job(JobStatus.inProgress, price: 1850.5, providerId: 'prov-1', payment: 'escrow'),
      fiscalDocsLoader: (_) async => const <Map<String, dynamic>>[],
    ),
  ),
  GalleryScreen(
    id: 'client/order_tracking_notas',
    title: 'Acompanhamento do pedido (com nota fiscal)',
    source: '$_dir/order_tracking_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => OrderTrackingScreen(
      job: _job(JobStatus.inProgress, price: 4300, providerId: 'prov-1', payment: 'escrow', title: _longTitle),
      fiscalDocsLoader: (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'nf-0001',
          'fiscal_document_mode': 'NFE_55',
          'emitter_cnpj': '12345678000199',
          'receipt_number': '000123456',
          'declared_material_amount': 1234.56,
          'clawback_triggered': false,
          'created_at': '2026-10-02T12:00:00Z',
        },
      ],
    ),
  ),
  GalleryScreen(
    id: 'client/waiting_quotes_vazio',
    title: 'Aguardando orçamentos (nenhum ainda)',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => WaitingQuotesScreen(
      job: _job(JobStatus.open, title: _longTitle),
      quotesStream: Stream<List<Quote>>.value(const <Quote>[]),
      invitesStream: Stream<List<JobInvite>>.value(const <JobInvite>[]),
    ),
  ),
  GalleryScreen(
    id: 'client/waiting_quotes_cheio',
    title: 'Aguardando orçamentos (3 recebidos)',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => WaitingQuotesScreen(
      job: _job(JobStatus.open, quotes: 3),
      quotesStream: Stream<List<Quote>>.value(<Quote>[
        _quote(1, 1850.5, message: 'Posso ir amanhã às 9h e levo todo o material necessário para o serviço.'),
        _quote(2, 990),
        _quote(3, 12500),
      ]),
      invitesStream: Stream<List<JobInvite>>.value(const <JobInvite>[]),
    ),
  ),
  GalleryScreen(
    id: 'client/rating',
    title: 'Avaliar o profissional',
    source: '$_dir/completion_screens.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => RatingScreen(
      job: _job(JobStatus.completed, price: 1850.5, providerId: 'prov-1', payment: 'released'),
      provider: SampleData.providerCard(name: 'Carlos Eduardo Silva de Albuquerque', i: 1),
    ),
  ),
  GalleryScreen(
    id: 'client/rating_success',
    title: 'Avaliação enviada',
    source: '$_dir/completion_screens.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => const RatingSuccessScreen(),
  ),
  GalleryScreen(
    id: 'client/rating_success_revelada',
    title: 'Avaliação enviada (revelada)',
    source: '$_dir/completion_screens.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => const RatingSuccessScreen(revealed: true),
  ),
  GalleryScreen(
    id: 'client/home_tab',
    title: 'Início do cliente (aba)',
    source: '$_dir/client_shell.dart',
    wave: 2,
    owner: _core,
    kind: GalleryKind.widget,
    modes: _client,
    overrides: (_) => walletOverrides(),
    animatesForever: true,
    note: 'Sem jobsStream injetado: streamMyJobs cai no estado vazio com Supabase fake.',
    builder: (_, _) => ClientHomeTab(profile: _profile(), onSeeOrders: () {}),
  ),
  GalleryScreen(
    id: 'client/shell',
    title: 'Shell do cliente (navegação por abas)',
    source: '$_dir/client_shell.dart',
    wave: 2,
    owner: _core,
    modes: _client,
    overrides: (_) => walletOverrides(),
    animatesForever: true,
    note: 'Abas sem stream injetado: estado vazio com Supabase fake.',
    builder: (_, _) => ClientShell(profile: _profile()),
  ),
  GalleryScreen(
    id: 'client/quote_received',
    title: 'Orçamento recebido',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => QuoteReceivedScreen(
      job: _job(JobStatus.open, title: _longTitle),
      quote: _quote(
        1,
        1850.5,
        message: 'Posso ir amanhã às 9h e levo todo o material necessário para o serviço.',
      ),
      provider: SampleData.providerCard(name: 'Carlos Eduardo Silva de Albuquerque', i: 1),
    ),
  ),
  GalleryScreen(
    id: 'client/payment',
    title: 'Pagamento do serviço',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    overrides: (_) => walletOverrides(),
    builder: (_, _) => PaymentScreen(
      job: _job(JobStatus.awaitingPayment, price: 1850.5, providerId: 'prov-1', title: _longTitle),
    ),
  ),
  GalleryScreen(
    id: 'client/completion',
    title: 'Serviço concluído',
    source: '$_dir/completion_screens.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    note: 'Sem loader injetado: renderiza o estado de conclusão com dados locais do Job.',
    builder: (_, _) => CompletionScreen(
      job: _job(JobStatus.completed, price: 1850.5, providerId: 'prov-1', payment: 'released'),
    ),
  ),
  GalleryScreen(
    id: 'client/provider_public_profile',
    title: 'Perfil público do profissional',
    source: '$_dir/provider_public_profile_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    note: 'Sem portfolioLoader injetado: portfólio cai no estado vazio com Supabase fake.',
    builder: (_, _) => ProviderPublicProfileScreen(
      provider: SampleData.providerCard(name: 'Carlos Eduardo Silva de Albuquerque', i: 1),
      profile: _profile(),
      category: 'Elétrica',
    ),
  ),
  // ----------------------------------------- ganchos §5.1 (Onda 3)
  GalleryScreen(
    id: 'client/client_job_cancelado',
    title: 'Pedido do cliente (roteador: cancelado)',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    builder: (_, _) => ClientJobScreen(
      jobId: 'j1',
      jobStreamOverride: Stream<Job?>.value(_job(JobStatus.canceled)),
    ),
  ),
  GalleryScreen(
    id: 'client/emergency_radar',
    title: 'Radar de emergência (procurando profissional)',
    source: '$_dir/client_job_screen.dart',
    wave: 3,
    owner: _orders,
    modes: _client,
    animatesForever: true,
    builder: (_, _) => EmergencyRadarScreen(
      job: SampleData.job(
        status: JobStatus.open,
        urgency: 'emergency',
        title: 'Vazamento grave no registro geral do banheiro',
        category: 'Hidráulica',
        price: 380,
      ),
      invitesStreamOverride: Stream<List<JobInvite>>.value(<JobInvite>[
        JobInvite(
          jobId: 'j1',
          providerId: SampleData.providerId,
          status: 'pending',
          expiresAt: DateTime.utc(2099, 1, 15, 12),
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ]),
      initialProvider: SampleData.providerCard(name: 'Carlos Eduardo Silva de Albuquerque', i: 1),
    ),
  ),
];
