import 'dart:async';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/models/wallet_models.dart';
import 'package:desperrengue_app/core/services/app_session.dart';
import 'package:desperrengue_app/core/services/profile_service.dart';
import 'package:desperrengue_app/core/services/wallet_service.dart';
import 'package:desperrengue_app/core/state/privacy_mode.dart';
import 'package:desperrengue_app/core/state/wallet_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ambiente determinístico da galeria: SharedPreferences em memória, Supabase
/// "inicializado" com cliente de mentira (nenhuma rede acontece: as chamadas
/// falham e as telas caem nos estados de erro/vazio) e singletons zerados.
///
/// Padrão idêntico ao dos testes existentes (`ui_polish_test.dart`,
/// `dossier_test.dart`): `Supabase.initialize(url: teste…, localStorage vazio)`.
abstract final class GalleryEnv {
  static bool _supabaseReady = false;

  /// Chame em `setUpAll` (idempotente).
  static Future<void> init() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    if (!_supabaseReady) {
      await Supabase.initialize(
        url: 'https://teste.supabase.co',
        publishableKey: 'chave-de-teste',
        authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), autoRefreshToken: false),
      );
      _supabaseReady = true;
    }
    resetSingletons();
  }

  /// Zera estado global entre cenários (chame em `setUp`).
  static void resetSingletons() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.reset();
    PrivacyMode.instance.hidden.value = false;
  }
}

// ----------------------------------------------------------------- dados

/// Dados de exemplo ricos (nomes longos, valores grandes) para estressar layout.
abstract final class SampleData {
  static const String longName = 'Maria Fernanda de Albuquerque e Souza Nascimento';
  static const String clientId = '00000000-0000-4000-8000-000000000001';
  static const String providerId = '00000000-0000-4000-8000-000000000002';

  static UserProfile clientProfile({bool provider = false}) => UserProfile(
        id: clientId,
        fullName: 'Ana Paula Souza',
        isClient: true,
        isProvider: provider,
        clientSetupDone: true,
        providerSetupDone: provider,
        lastMode: UserMode.client,
        verificationStatus: VerificationStatus.active,
        phone: '(11) 98765-4321',
        addressLine: 'Rua das Acácias, 123 - Apto 45, Jardim América',
        addressCity: 'São Paulo - SP',
        cpfMasked: '***.456.789-**',
      );

  static UserProfile providerProfile() => UserProfile(
        id: providerId,
        fullName: 'João Carlos Ferreira',
        isClient: true,
        isProvider: true,
        clientSetupDone: true,
        providerSetupDone: true,
        lastMode: UserMode.provider,
        verificationStatus: VerificationStatus.active,
        phone: '(11) 91234-5678',
        addressCity: 'São Paulo - SP',
        completedJobsCount: 48,
      );

  static UserProfile firstAccessProfile() => const UserProfile(id: clientId, fullName: 'Ana Paula Souza');

  static ProviderCard providerCard({String name = 'João Carlos Ferreira', int i = 0}) => ProviderCard(
        id: 'prov-$i',
        fullName: name,
        city: 'São Paulo - SP',
        headline: 'Eletricista residencial · NR-10',
        specialties: const ['Elétrica', 'Iluminação', 'Ar-condicionado'],
        hourlyRate: 90,
        visitFee: 30,
        ratingAvg: 4.8,
        ratingCount: 127,
        jobsDone: 342,
        distanceKm: 3.4,
        badges: const <String>[],
      );

  static Job job({
    String id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    JobStatus status = JobStatus.open,
    String title = 'Trocar disjuntor e revisar quadro de luz',
    String category = 'Elétrica',
    double? price,
    String urgency = 'scheduled',
    String? providerId,
    String paymentStatus = 'pending',
  }) =>
      Job(
        id: id,
        clientId: clientId,
        title: title,
        description: 'O disjuntor desarma toda vez que ligo o chuveiro e o forno ao mesmo tempo. '
            'Preciso de alguém para revisar o quadro de luz com segurança.',
        category: category,
        status: status,
        paymentStatus: paymentStatus,
        urgency: urgency,
        visibility: 'open',
        createdAt: DateTime(2026, 10, 1, 14, 30),
        providerId: providerId,
        agreedPrice: price,
        budgetEstimate: price,
        addressSummary: 'Jardim América, São Paulo - SP',
        quoteCount: 3,
      );

  static ClientWallet wallet({int available = 123456, int escrow = 45000}) =>
      ClientWallet(availableCents: available, escrowCents: escrow);

  static List<WalletEntry> statement() => <WalletEntry>[
        WalletEntry(
          id: 'e1',
          kind: WalletEntryKind.topup,
          title: 'Recarga via Pix',
          deltaAvailableCents: 50000,
          deltaEscrowCents: 0,
          createdAt: DateTime(2026, 10, 2, 9, 5),
        ),
        WalletEntry(
          id: 'e2',
          kind: WalletEntryKind.hold,
          title: 'Reserva: Trocar disjuntor e revisar quadro de luz',
          deltaAvailableCents: -45000,
          deltaEscrowCents: 45000,
          createdAt: DateTime(2026, 10, 3, 10, 0),
        ),
        WalletEntry(
          id: 'e3',
          kind: WalletEntryKind.release,
          title: 'Pagamento liberado ao profissional',
          deltaAvailableCents: 0,
          deltaEscrowCents: -45000,
          createdAt: DateTime(2026, 10, 5, 18, 40),
        ),
      ];
}

// ------------------------------------------------------------------ fakes

/// `ProfileService` de mentira: nenhum acesso a Supabase. Pode ser entregue às
/// telas que aceitem injeção (ou usado após refatoração do dono da tela).
class FakeProfileService extends Fake implements ProfileService {
  FakeProfileService({this.profile, this.failFetch = false});

  UserProfile? profile;
  final bool failFetch;
  final List<String> calls = <String>[];

  @override
  Future<UserProfile?> fetchCurrent() async {
    calls.add('fetchCurrent');
    if (failFetch) throw StateError('falha simulada');
    return profile;
  }

  @override
  Future<UserProfile?> cachedProfile() async => profile;

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> setLastMode(UserMode mode) async => calls.add('setLastMode:${mode.wire}');

  @override
  Future<void> updateProfile(Map<String, dynamic> values) async => calls.add('updateProfile');

  @override
  Future<VerificationStatus> activateProvider() async {
    calls.add('activateProvider');
    return VerificationStatus.active;
  }
}

/// `WalletService` de mentira (saldo/extrato fixos, Pix controlável).
class FakeWalletService extends Fake implements WalletService {
  FakeWalletService({ClientWallet? wallet, List<WalletEntry>? statement, this.walletError})
      : _wallet = wallet ?? SampleData.wallet(),
        _statement = statement ?? SampleData.statement();

  final ClientWallet _wallet;
  final List<WalletEntry> _statement;
  final Object? walletError;
  final StreamController<PixTopup> topupCtl = StreamController<PixTopup>.broadcast();

  @override
  Future<ClientWallet> wallet() async => _wallet;

  @override
  Stream<ClientWallet> walletStream() =>
      walletError != null ? Stream<ClientWallet>.error(walletError!) : Stream<ClientWallet>.value(_wallet);

  @override
  Stream<List<WalletEntry>> statementStream({int limit = 60}) => Stream<List<WalletEntry>>.value(_statement);

  @override
  Future<PixTopup> createTopup(int amountCents, String idempotencyKey) async => PixTopup(
        id: 'tp1',
        amountCents: amountCents,
        txid: 'DSP0000000000000000000001',
        brcode: '00020101021226...6304ABCD',
        status: TopupStatus.pending,
        expiresAt: DateTime(2026, 10, 1, 15, 0),
      );

  @override
  Stream<PixTopup> topupStream(String id) => topupCtl.stream;

  @override
  Future<void> simulatePayment(String topupId) async {}
}

/// Overrides Riverpod padrão da carteira (cliente).
List<Override> walletOverrides({FakeWalletService? service}) => <Override>[
      walletServiceProvider.overrideWithValue(service ?? FakeWalletService()),
    ];
