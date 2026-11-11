/// Conquistas (gamificação) do CLIENTE — modelo puro e testável.
///
/// Mesmo "estilo troféu" das conquistas do profissional: cada conquista é uma categoria com
/// níveis (bronze → diamante). Diferente do profissional (persistido no banco), estas são
/// calculadas em **uma única passagem O(N)** sobre o histórico de pedidos que já está em
/// memória: nenhuma consulta extra por conquista e o resultado é sempre consistente com os
/// pedidos exibidos.
library;

import 'achievements.dart' show AchievementTier;
import 'marketplace_models.dart';
import 'user_profile.dart';
import '../utils/tag_normalizer.dart';

/// Códigos das 6 conquistas do cliente.
enum ClientAchievementCode {
  firstOrder,
  verifiedClient,
  collaborativeReviewer,
  homeMaster,
  secureWallet,
  loyalClient,
}

/// Um nível (medalha) de uma conquista.
class ClientLevel {
  const ClientLevel(this.threshold, this.tier, this.title);

  /// Quantidade necessária da métrica.
  final int threshold;
  final AchievementTier tier;

  /// Nome curto da medalha ("Boas-vindas ao Desperrengue", "10 pedidos realizados").
  final String title;
}

/// Definição estática (textos, métrica e níveis).
class ClientAchievementDef {
  const ClientAchievementDef({
    required this.code,
    required this.name,
    required this.title,
    required this.description,
    required this.unit,
    required this.levels,
  });

  final ClientAchievementCode code;

  /// Nome da conquista ("1º Pedido Realizado").
  final String name;

  /// Selo do 1º nível ("Boas-vindas ao Desperrengue").
  final String title;
  final String description;

  /// Unidade da métrica ("pedidos", "categorias"…), usada em "2/3 categorias".
  final String unit;
  final List<ClientLevel> levels;

  /// Meta do 1º nível: desbloqueia a conquista.
  int get goal => levels.first.threshold;
}

const List<ClientAchievementDef> kClientAchievements = [
  ClientAchievementDef(
    code: ClientAchievementCode.firstOrder,
    name: '1º Pedido Realizado',
    title: 'Boas-vindas ao Desperrengue',
    description: 'Publique ou conclua o seu primeiro serviço e siga pedindo: cada pedido conta.',
    unit: 'pedidos',
    levels: [
      ClientLevel(1, AchievementTier.bronze, '1º pedido realizado'),
      ClientLevel(5, AchievementTier.silver, '5 pedidos realizados'),
      ClientLevel(10, AchievementTier.gold, '10 pedidos realizados'),
      ClientLevel(25, AchievementTier.platinum, '25 pedidos realizados'),
      ClientLevel(50, AchievementTier.diamond, '50 pedidos realizados'),
    ],
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.verifiedClient,
    name: 'Cliente Verificado',
    title: 'Identidade Confirmada',
    description: 'Complete o perfil: nome, telefone, endereço e cadastro de cliente.',
    unit: 'itens do perfil',
    levels: [ClientLevel(4, AchievementTier.gold, 'Identidade confirmada')],
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.collaborativeReviewer,
    name: 'Avaliador Colaborativo',
    title: 'Voz da Comunidade',
    description: 'Avalie os profissionais depois de cada serviço concluído: você ajuda quem vem depois.',
    unit: 'avaliações',
    levels: [
      ClientLevel(1, AchievementTier.bronze, 'Voz da Comunidade'),
      ClientLevel(5, AchievementTier.silver, '5 avaliações feitas'),
      ClientLevel(10, AchievementTier.gold, '10 avaliações feitas'),
      ClientLevel(25, AchievementTier.platinum, '25 avaliações feitas'),
    ],
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.homeMaster,
    name: 'Mestre do Lar',
    title: 'Multicategorias',
    description: 'Solicite serviços em categorias diferentes: do chuveiro ao jardim.',
    unit: 'categorias',
    levels: [
      ClientLevel(3, AchievementTier.bronze, '3 categorias diferentes'),
      ClientLevel(5, AchievementTier.silver, '5 categorias diferentes'),
      ClientLevel(8, AchievementTier.gold, '8 categorias diferentes'),
      ClientLevel(12, AchievementTier.platinum, '12 categorias diferentes'),
    ],
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.secureWallet,
    name: 'Pagamento 100% Seguro',
    title: 'Guardião da Carteira',
    description: 'Conclua serviços com o pagamento protegido em custódia e sem nenhuma contestação.',
    unit: 'serviços seguros',
    levels: [
      ClientLevel(3, AchievementTier.bronze, '3 serviços 100% seguros'),
      ClientLevel(10, AchievementTier.silver, '10 serviços 100% seguros'),
      ClientLevel(25, AchievementTier.gold, '25 serviços 100% seguros'),
    ],
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.loyalClient,
    name: 'Cliente Fidelidade',
    title: 'VIP Desperrengue',
    description: 'Conclua serviços com sucesso. Quanto mais você usa, maior a sua medalha.',
    unit: 'serviços',
    levels: [
      ClientLevel(5, AchievementTier.bronze, '5 serviços concluídos'),
      ClientLevel(10, AchievementTier.silver, '10 serviços concluídos'),
      ClientLevel(25, AchievementTier.gold, '25 serviços concluídos'),
      ClientLevel(50, AchievementTier.platinum, '50 serviços concluídos'),
      ClientLevel(100, AchievementTier.diamond, '100 serviços concluídos'),
    ],
  ),
];

/// Total de medalhas (soma dos níveis de todas as conquistas).
int get kClientMedalTotal => kClientAchievements.fold(0, (a, d) => a + d.levels.length);

/// Estado de uma conquista para o usuário.
class ClientAchievementProgress {
  const ClientAchievementProgress({required this.def, required this.current});

  final ClientAchievementDef def;

  /// Valor atual da métrica (pode passar da meta).
  final int current;

  /// Conquista desbloqueada = 1º nível alcançado.
  bool get unlocked => current >= def.goal;

  /// Níveis (medalhas) já conquistados.
  List<ClientLevel> get unlockedLevels => [for (final l in def.levels) if (current >= l.threshold) l];
  int get unlockedCount => unlockedLevels.length;

  /// Maior nível conquistado (null = nenhum).
  ClientLevel? get highest => unlockedLevels.isEmpty ? null : unlockedLevels.last;

  /// Próximo nível a conquistar (null = categoria completa).
  ClientLevel? get next {
    for (final l in def.levels) {
      if (current < l.threshold) return l;
    }
    return null;
  }

  /// Valor exibido na meta do 1º nível ("2/3"): nunca passa da meta.
  int get shown => current > def.goal ? def.goal : current;

  /// 0..1 rumo ao PRÓXIMO nível (1 quando a categoria está completa).
  double get fractionToNext {
    final n = next;
    if (n == null) return 1;
    final prev = highest?.threshold ?? 0;
    return ((current - prev) / (n.threshold - prev)).clamp(0.0, 1.0);
  }
}

/// Dados de entrada (já em memória).
class ClientAchievementInput {
  const ClientAchievementInput({
    required this.jobs,
    this.profileSteps = 0,
    this.reviewedJobIds = const {},
    this.contestedJobIds = const {},
  });

  /// Todos os pedidos do cliente.
  final List<Job> jobs;

  /// Quantos dos 4 itens do perfil estão completos (ver [profileCompletionSteps]).
  final int profileSteps;

  /// Serviços que o cliente já avaliou.
  final Set<String> reviewedJobIds;

  /// Serviços em que houve contestação (aberta pelo cliente).
  final Set<String> contestedJobIds;
}

/// Itens completos do perfil do cliente (0..4): nome real, telefone, endereço e cadastro.
int profileCompletionSteps(UserProfile p) {
  var n = 0;
  final name = p.fullName.trim();
  if (p.hasVerifiedCivilIdentity) return 4;
  final verifiedName = (p.verifiedFullName ?? '').trim();
  if ((name.isNotEmpty && name != 'Usuário' && !name.contains('@')) || (verifiedName.isNotEmpty && !verifiedName.contains('@'))) n++;
  if ((p.phone ?? '').trim().isNotEmpty) n++;
  if ((p.addressLine ?? '').trim().isNotEmpty) n++;
  if (p.clientSetupDone) n++;
  return n;
}

/// Calcula as 6 conquistas com UMA passagem sobre [ClientAchievementInput.jobs] — O(N) —
/// e lookups O(1) em `Set` para avaliações e contestações.
List<ClientAchievementProgress> computeClientAchievements(ClientAchievementInput input) {
  var orders = 0;
  var completed = 0;
  var secure = 0;
  var reviewed = 0;
  final categories = <String>{};

  for (final j in input.jobs) {
    orders++;
    final slug = canonicalTag(j.category);
    if (slug.isNotEmpty) categories.add(slug);
    if (j.status == JobStatus.completed) {
      completed++;
      if (j.reservePaid && !input.contestedJobIds.contains(j.id)) secure++;
      if (input.reviewedJobIds.contains(j.id)) reviewed++;
    }
  }

  int value(ClientAchievementCode c) => switch (c) {
        ClientAchievementCode.firstOrder => orders,
        ClientAchievementCode.verifiedClient => input.profileSteps,
        ClientAchievementCode.collaborativeReviewer => reviewed,
        ClientAchievementCode.homeMaster => categories.length,
        ClientAchievementCode.secureWallet => secure,
        ClientAchievementCode.loyalClient => completed,
      };

  return [for (final d in kClientAchievements) ClientAchievementProgress(def: d, current: value(d.code))];
}
