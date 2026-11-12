import '../models/marketplace_models.dart' show JobStatus;

/// Motor de domínio PURO (sem Flutter, sem Supabase, sem `dart:io`) da trava
/// Temporal & Spatial Geo-Privacy Lock.
///
/// IMPORTANTE: esta é a 2ª camada (UX / defesa em profundidade). A coordenada
/// exata e o endereço completo NUNCA devem chegar ao dispositivo do profissional
/// antes do desbloqueio — isso é garantido no servidor (RPC
/// `get_job_location_for_viewer`). Aqui não existe jitter nem geração de centro
/// aproximado: o centro fuzzy vem pronto do servidor.
///
/// Fuso: Brasil não tem horário de verão desde 2019, então `America/Sao_Paulo`
/// é UTC−3 fixo. O desbloqueio acontece às 00h00 (UTC−3) do dia agendado, sem
/// depender do fuso do aparelho.

/// Quem está olhando o endereço.
enum GeoViewerRole { owner, provider }

/// Fase da trava de privacidade.
enum GeoPrivacyPhase { ownerFull, openQuoting, confirmedFuture, serviceDay, closed }

/// Resultado da avaliação da política.
class GeoPrivacyDecision {
  const GeoPrivacyDecision({
    required this.phase,
    required this.exactUnlocked,
    required this.showStreetAndNumber,
    required this.showComplement,
    required this.showExactMap,
    required this.showRoute,
    required this.showApproximateArea,
    this.scheduledDay,
    this.unlockAt,
    this.lockMessage,
  });

  final GeoPrivacyPhase phase;

  /// `true` quando rua, número, complemento, mapa exato e rota podem ser exibidos.
  final bool exactUnlocked;
  final bool showStreetAndNumber;
  final bool showComplement;
  final bool showExactMap;
  final bool showRoute;

  /// Círculo de raio aproximado (centro fuzzy do servidor) + bairro/cidade.
  final bool showApproximateArea;

  /// Dia agendado no calendário de São Paulo, como `DateTime.utc(ano, mês, dia)`
  /// (apenas a data é significativa).
  final DateTime? scheduledDay;

  /// Instante do desbloqueio (00h00 em UTC−3 do dia agendado), em UTC.
  final DateTime? unlockAt;

  /// Aviso pt-BR para a UI; `null` quando não há trava a explicar.
  final String? lockMessage;
}

class GeoPrivacyPolicyEngine {
  const GeoPrivacyPolicyEngine._();

  /// Deslocamento fixo de America/Sao_Paulo em relação ao UTC.
  static const Duration saoPauloOffset = Duration(hours: -3);

  /// Agora em horário de São Paulo, como `DateTime` com flag UTC cujos campos
  /// (ano/mês/dia/hora…) representam o relógio de parede de São Paulo.
  static DateTime nowSaoPaulo([DateTime? now]) => toSaoPaulo(now ?? DateTime.now());

  /// Converte um instante absoluto para o relógio de parede de São Paulo
  /// (retorno com flag UTC; use só os campos, nunca `.toLocal()`).
  static DateTime toSaoPaulo(DateTime instant) => instant.toUtc().add(saoPauloOffset);

  /// Dia do calendário de São Paulo de um instante (`DateTime.utc(a, m, d)`).
  static DateTime saoPauloDay(DateTime instant) {
    final sp = toSaoPaulo(instant);
    return DateTime.utc(sp.year, sp.month, sp.day);
  }

  /// Instante (UTC) em que o dia de São Paulo [day] começa (00h00 UTC−3).
  static DateTime unlockInstantFor(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).subtract(saoPauloOffset);

  /// `DD/MM/AAAA` a partir dos campos de [day] (sem conversão de fuso).
  static String formatDate(DateTime day) {
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    final y = day.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  static GeoPrivacyDecision evaluate({
    required GeoViewerRole role,
    required JobStatus status,
    DateTime? scheduledFor,
    bool isEmergency = false,
    bool isAssignedProvider = false,
    DateTime? now,
  }) {
    if (role == GeoViewerRole.owner) {
      return const GeoPrivacyDecision(
        phase: GeoPrivacyPhase.ownerFull,
        exactUnlocked: true,
        showStreetAndNumber: true,
        showComplement: true,
        showExactMap: true,
        showRoute: true,
        showApproximateArea: false,
      );
    }

    // --- Profissional ---------------------------------------------------
    final today = saoPauloDay(now ?? DateTime.now());
    final day = scheduledFor == null ? null : saoPauloDay(scheduledFor);
    final unlockAt = day == null ? null : unlockInstantFor(day);

    // Encerrado: re-bloqueio permanente (LGPD).
    if (status == JobStatus.completed ||
        status == JobStatus.canceled ||
        status == JobStatus.disputed) {
      return _locked(GeoPrivacyPhase.closed, day, unlockAt);
    }

    // Sem orçamento aceito para este profissional: só área aproximada.
    final accepted = isAssignedProvider &&
        (status == JobStatus.awaitingPayment ||
            status == JobStatus.scheduled ||
            status == JobStatus.inProgress ||
            status == JobStatus.awaitingApproval);
    if (!accepted) {
      return _locked(GeoPrivacyPhase.openQuoting, day, unlockAt);
    }

    // Serviço já iniciado: permanece liberado até o encerramento.
    if (status == JobStatus.inProgress || status == JobStatus.awaitingApproval) {
      return _unlocked(day, unlockAt);
    }

    // Aguardando pagamento: nunca libera (o pagamento ainda não foi confirmado).
    if (status == JobStatus.awaitingPayment) {
      return _locked(GeoPrivacyPhase.confirmedFuture, day, unlockAt, today: today);
    }

    // status == scheduled (aceito e pago).
    if (day == null) {
      // Emergência sem data com orçamento aceito/pago libera na hora;
      // sem data e sem emergência: trava (fail-closed).
      return isEmergency
          ? _unlocked(day, unlockAt)
          : _locked(GeoPrivacyPhase.confirmedFuture, day, unlockAt, today: today);
    }
    if (!today.isBefore(day)) return _unlocked(day, unlockAt);
    return _locked(GeoPrivacyPhase.confirmedFuture, day, unlockAt, today: today);
  }

  /// Mensagem pt-BR da trava para [phase]. `null` quando não há trava.
  /// [scheduledDay] é o dia agendado (apenas campos de data são usados).
  static String? lockMessageFor(
    GeoPrivacyPhase phase, {
    DateTime? scheduledDay,
    bool dayReached = false,
  }) {
    switch (phase) {
      case GeoPrivacyPhase.ownerFull:
      case GeoPrivacyPhase.serviceDay:
        return null;
      case GeoPrivacyPhase.openQuoting:
        return '🔒 Endereço Protegido por Segurança: por segurança residencial, o nome da rua, '
            'o número e o mapa com a rota exata só são liberados depois que o cliente confirmar '
            'o seu orçamento, no dia agendado. Por enquanto você vê apenas a região aproximada.';
      case GeoPrivacyPhase.confirmedFuture:
        if (scheduledDay == null || dayReached) {
          return '🔒 Endereço Protegido por Segurança: você já está confirmado neste atendimento! '
              'Por segurança residencial, o nome da rua, número da casa/apartamento e o mapa com '
              'a rota exata serão liberados automaticamente assim que o serviço estiver pago e pronto para começar.';
        }
        return '🔒 Endereço Protegido por Segurança: você já está confirmado neste atendimento! '
            'Por segurança residencial, o nome da rua, número da casa/apartamento e o mapa com '
            'a rota exata serão liberados automaticamente às 00h00 do dia agendado '
            '(${formatDate(scheduledDay)}).';
      case GeoPrivacyPhase.closed:
        return '🔒 Atendimento encerrado: por privacidade e segurança do cliente (LGPD), '
            'o endereço completo e a rota não ficam mais disponíveis.';
    }
  }

  static GeoPrivacyDecision _unlocked(DateTime? day, DateTime? unlockAt) {
    return GeoPrivacyDecision(
      phase: GeoPrivacyPhase.serviceDay,
      exactUnlocked: true,
      showStreetAndNumber: true,
      showComplement: true,
      showExactMap: true,
      showRoute: true,
      showApproximateArea: false,
      scheduledDay: day,
      unlockAt: unlockAt,
    );
  }

  static GeoPrivacyDecision _locked(
    GeoPrivacyPhase phase,
    DateTime? day,
    DateTime? unlockAt, {
    DateTime? today,
  }) {
    final dayReached = day != null && today != null && !today.isBefore(day);
    return GeoPrivacyDecision(
      phase: phase,
      exactUnlocked: false,
      showStreetAndNumber: false,
      showComplement: false,
      showExactMap: false,
      showRoute: false,
      showApproximateArea: phase != GeoPrivacyPhase.closed,
      scheduledDay: phase == GeoPrivacyPhase.openQuoting ? null : day,
      unlockAt: phase == GeoPrivacyPhase.openQuoting ? null : unlockAt,
      lockMessage: lockMessageFor(phase, scheduledDay: day, dayReached: dayReached),
    );
  }
}

/// Visão da localização do serviço para quem está olhando, vinda da RPC
/// `get_job_location_for_viewer`. Defensiva: nunca expõe rua/número/complemento/
/// referência/CEP (nem coordenada exata) quando `exact_unlocked != true`, mesmo
/// que o servidor os envie por engano.
class ProviderLocationView {
  const ProviderLocationView({
    required this.phase,
    required this.exactUnlocked,
    this.city = '',
    this.uf = '',
    this.neighborhood = '',
    this.street,
    this.number,
    this.complement,
    this.reference,
    this.cep,
    this.lat,
    this.lng,
    this.radiusM = 800,
    this.scheduledDate,
    this.unlockAt,
  });

  final GeoPrivacyPhase phase;
  final bool exactUnlocked;
  final String city;
  final String uf;
  final String neighborhood;
  final String? street;
  final String? number;
  final String? complement;
  final String? reference;
  final String? cep;

  /// Exatos se [exactUnlocked]; senão, centro FUZZY (deslocado no servidor).
  /// `null` quando fechado/negado.
  final double? lat;
  final double? lng;
  final int radiusM;

  /// Dia agendado (`DateTime.utc(a, m, d)`, calendário de São Paulo).
  final DateTime? scheduledDate;
  final DateTime? unlockAt;

  /// Raio mínimo aceito para o círculo travado (um círculo menor revelaria mais).
  static const int minLockedRadiusM = 500;
  static const int defaultLockedRadiusM = 800;
  static const int defaultUnlockedRadiusM = 100;

  factory ProviderLocationView.fromRpc(Map<String, dynamic> m) {
    final rawPhase = _str(m['phase']);
    final role = _str(m['viewer_role']);
    var phase = _phaseFrom(rawPhase);
    final denied = rawPhase == 'denied' || role == 'none';
    if (denied) phase = GeoPrivacyPhase.closed;

    final wantsUnlock = m['exact_unlocked'] == true &&
        !denied &&
        (phase == GeoPrivacyPhase.ownerFull || phase == GeoPrivacyPhase.serviceDay);
    // Servidor inconsistente (fase destravada sem flag, ou flag sem fase): trava.
    if (!wantsUnlock &&
        (phase == GeoPrivacyPhase.ownerFull || phase == GeoPrivacyPhase.serviceDay)) {
      phase = GeoPrivacyPhase.openQuoting;
    }
    final unlocked = wantsUnlock;
    final closed = phase == GeoPrivacyPhase.closed;

    double? lat = _coord(m['lat'], 90);
    double? lng = _coord(m['lng'], 180);
    if (lat == null || lng == null || closed) {
      lat = null;
      lng = null;
    }

    final rawRadius = _int(m['radius_m']);
    final radius = unlocked
        ? (rawRadius != null && rawRadius > 0 ? rawRadius : defaultUnlockedRadiusM)
        : (rawRadius == null || rawRadius < minLockedRadiusM ? defaultLockedRadiusM : rawRadius);

    return ProviderLocationView(
      phase: phase,
      exactUnlocked: unlocked,
      city: denied ? '' : _str(m['city']),
      uf: denied ? '' : _str(m['uf']),
      neighborhood: denied ? '' : _str(m['neighborhood']),
      street: unlocked ? _nullable(m['street']) : null,
      number: unlocked ? _nullable(m['number']) : null,
      complement: unlocked ? _nullable(m['complement']) : null,
      reference: unlocked ? _nullable(m['reference']) : null,
      cep: unlocked ? _nullable(m['cep']) : null,
      lat: lat,
      lng: lng,
      radiusM: radius,
      scheduledDate: _date(m['scheduled_date']),
      unlockAt: _instant(m['unlock_at']),
    );
  }

  /// Como [fromRpc], mas devolve `null` quando o acesso foi negado
  /// (`phase == 'denied'`, `viewer_role == 'none'`) ou o payload é vazio.
  static ProviderLocationView? tryFromRpc(Object? raw) {
    if (raw is! Map || raw.isEmpty) return null;
    final m = Map<String, dynamic>.from(raw);
    if (_str(m['phase']) == 'denied' || _str(m['viewer_role']) == 'none') return null;
    return ProviderLocationView.fromRpc(m);
  }

  /// Ex.: `Country Club • Poços de Caldas - MG`.
  String get areaTitle {
    final cityUf = [city, uf].where((s) => s.isNotEmpty).join(' - ');
    final parts = [neighborhood, cityUf].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Localização protegida' : parts.join(' • ');
  }

  /// Ex.: `Avenida Padre Cletus, 1661 - Apto 12`; `null` enquanto travado.
  String? get fullStreetLine {
    if (!exactUnlocked) return null;
    final st = street?.trim() ?? '';
    if (st.isEmpty) return null;
    final nr = number?.trim() ?? '';
    final cp = complement?.trim() ?? '';
    final base = nr.isEmpty ? st : '$st, $nr';
    return cp.isEmpty ? base : '$base - $cp';
  }

  /// Aviso pt-BR da trava (null quando liberado/dono).
  String? get lockMessage {
    final day = scheduledDate;
    var reached = false;
    if (day != null) {
      reached = !GeoPrivacyPolicyEngine.saoPauloDay(DateTime.now()).isBefore(day);
    }
    return GeoPrivacyPolicyEngine.lockMessageFor(phase, scheduledDay: day, dayReached: reached);
  }

  /// Mapa exato / rota só quando destravado e com coordenadas.
  bool get canShowExactMap => exactUnlocked && lat != null && lng != null;

  /// Círculo aproximado só quando travado (não fechado) e com centro fuzzy.
  bool get canShowApproximateArea =>
      !exactUnlocked && phase != GeoPrivacyPhase.closed && lat != null && lng != null;

  static GeoPrivacyPhase _phaseFrom(String raw) {
    switch (raw) {
      case 'owner_full':
        return GeoPrivacyPhase.ownerFull;
      case 'confirmed_future':
        return GeoPrivacyPhase.confirmedFuture;
      case 'service_day':
        return GeoPrivacyPhase.serviceDay;
      case 'closed':
      case 'denied':
        return GeoPrivacyPhase.closed;
      case 'open_quoting':
      default:
        // Fase ausente/desconhecida: a mais restritiva que ainda mostra a região.
        return GeoPrivacyPhase.openQuoting;
    }
  }

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  static String? _nullable(Object? v) {
    final s = _str(v);
    return s.isEmpty ? null : s;
  }

  static int? _int(Object? v) {
    if (v is num) return v.isFinite ? v.round() : null;
    if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.round();
    return null;
  }

  static double? _coord(Object? v, double limit) {
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim());
    }
    if (d == null || !d.isFinite || d.abs() > limit) return null;
    return d;
  }

  static DateTime? _date(Object? v) {
    final s = _str(v);
    if (s.length < 10) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final mo = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, mo, d);
  }

  static DateTime? _instant(Object? v) {
    final s = _str(v);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toUtc();
  }
}
