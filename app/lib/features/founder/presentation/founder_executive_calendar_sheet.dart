import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/money.dart';
import 'founder_animations_and_shaders.dart';

const List<String> _kMonthsPt = <String>[
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> _kWeekdaysShortPt = <String>[
  'SEG',
  'TER',
  'QUA',
  'QUI',
  'SEX',
  'SÁB',
  'DOM',
];

const List<String> _kWeekdaysLongPt = <String>[
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

class _CalendarWindowChoice {
  const _CalendarWindowChoice(this.key, this.label);
  final String key;
  final String label;
}

const List<_CalendarWindowChoice> _kCalendarWindows = <_CalendarWindowChoice>[
  _CalendarWindowChoice('today', 'Hoje'),
  _CalendarWindowChoice('7d', '7 dias'),
  _CalendarWindowChoice('30d', '30 dias'),
  _CalendarWindowChoice('90d', '90 dias'),
  _CalendarWindowChoice('365d', 'Este ano'),
  _CalendarWindowChoice('all', 'Tudo'),
];

String _toIsoDay(DateTime d) => CeoBrazilFiscalCalendar.formatDayIso(d);

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatFullDayPt(DateTime d, DateTime today) {
  final prefix = _isSameCalendarDay(d, today)
      ? 'Hoje · '
      : '${_kWeekdaysLongPt[(d.weekday - 1).clamp(0, 6)]}, ';
  final monthName = _kMonthsPt[(d.month - 1).clamp(0, 11)].toLowerCase();
  return '$prefix${d.day} de $monthName de ${d.year}';
}

String _humanizeAgendaBadgeLabel(CeoCalendarAgendaEvent ev) {
  final raw = ev.codeLabel.trim();
  if (raw.toUpperCase() == 'FIXED_OPEX') return 'GASTO FIXO';
  if (raw.toUpperCase() == 'VARIABLE_PSP_CLOUD') return 'TAXA PIX';
  if (raw.toUpperCase() == 'TAX_EXTRA') return 'IMPOSTO';
  return raw;
}

FounderIconGlyph _glyphForAgendaEvent(CeoCalendarAgendaEvent ev) {
  switch (ev.eventKind) {
    case 'COMPLETED_ORDER':
      return FounderIconGlyph.checkValid;
    case 'SCHEDULED_ORDER':
      return FounderIconGlyph.upcomingEvent;
    case 'MEDIATION_OPENED':
    case 'MEDIATION_SLA_DUE':
    case 'SUPPORT_DISPUTE_OPENED':
    case 'SUPPORT_DISPUTE_SLA_DUE':
      return FounderIconGlyph.mediationBalance;
    case 'TAX_DAS_DUE':
    case 'FISCAL_DEFIS_DECLARATION':
      return FounderIconGlyph.taxBankDas;
    case 'COMPANY_EXPENSE':
      return ev.isScheduledExpense
          ? FounderIconGlyph.expenseReceipt
          : FounderIconGlyph.checkValid;
    case 'ESCROW_MATURATION_RELEASE':
      return FounderIconGlyph.pixDiamond;
    case 'SEFAZ_AUDIT_DEADLINE':
      return FounderIconGlyph.nfeBarcode;
    default:
      return FounderIconGlyph.shieldVerified;
  }
}

Color _colorForAgendaEvent(CeoCalendarAgendaEvent ev) {
  switch (ev.eventKind) {
    case 'COMPLETED_ORDER':
      return FounderSovereignTokens.solvencyEmerald;
    case 'SCHEDULED_ORDER':
      return FounderSovereignTokens.imperialGoldBright;
    case 'MEDIATION_OPENED':
    case 'MEDIATION_SLA_DUE':
    case 'SUPPORT_DISPUTE_OPENED':
    case 'SUPPORT_DISPUTE_SLA_DUE':
      return ev.severity == 'CRITICAL'
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.warmAmber;
    case 'TAX_DAS_DUE':
    case 'FISCAL_DEFIS_DECLARATION':
      return ev.statusCode == 'PAID'
          ? FounderSovereignTokens.solvencyEmerald
          : (ev.grossCents > 0
              ? FounderSovereignTokens.warmAmber
              : FounderSovereignTokens.imperialGoldBright);
    case 'COMPANY_EXPENSE':
      return ev.isScheduledExpense
          ? FounderSovereignTokens.warmAmber
          : FounderSovereignTokens.secondaryInk;
    case 'ESCROW_MATURATION_RELEASE':
      return FounderSovereignTokens.imperialGoldBright;
    case 'SEFAZ_AUDIT_DEADLINE':
      return FounderSovereignTokens.warmAmber;
    default:
      return FounderSovereignTokens.secondaryInk;
  }
}

/// Resultado tipado retornado ao confirmar `Concluir consulta` no Calendário Executivo.
class FounderCalendarSelectionResult {
  const FounderCalendarSelectionResult({
    required this.windowKey,
    required this.isSingleDay,
    required this.selectedDate,
  });

  /// Chave canônica para `ceo_get_live_cockpit_snapshot`:
  /// - `'day:YYYY-MM-DD'` quando uma data específica (passada, hoje ou futura) foi escolhida;
  /// - `'today' | '7d' | '30d' | '90d' | '365d' | 'all'` quando um período agregado está ativo.
  final String windowKey;
  final bool isSingleDay;
  final DateTime selectedDate;
}

/// Calendário Executivo *Luxo Silencioso* (Obsidiana & Ouro Champagne Acetinado)
/// com sincronização em tempo real (`Desperrengue` <-> `Desperrengue CEO`) e agenda futura real.
class FounderExecutiveCalendarSheet extends StatefulWidget {
  const FounderExecutiveCalendarSheet._({
    super.key,
    required this.isSingleDatePicker,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.snapshot,
    this.liveSnapshotStream,
    this.selectedWindowKey = '30d',
    this.onSelectWindow,
    this.onInspectOrder,
    this.onAddExpenseForDate,
    this.onToggleExpensePaid,
    this.privacyBlurActive = false,
  });

  final bool isSingleDatePicker;
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final FounderDashboardSnapshot? snapshot;
  final Stream<FounderDashboardSnapshot>? liveSnapshotStream;
  final String selectedWindowKey;
  final ValueChanged<String>? onSelectWindow;
  final void Function(String jobId, String? orderCode)? onInspectOrder;
  final Future<void> Function(DateTime initialDate)? onAddExpenseForDate;
  final Future<void> Function(String expenseId, bool paid)? onToggleExpensePaid;
  final bool privacyBlurActive;

  /// Abre o Calendário Executivo completo (passado, hoje e datas futuras reais:
  /// impostos DAS previstos, mediações/chamados, serviços agendados, custódia e contas)
  /// e devolve a seleção confirmada em `Concluir consulta`.
  static Future<FounderCalendarSelectionResult?> showExecutiveOverview(
    BuildContext context, {
    required FounderDashboardSnapshot snapshot,
    required String selectedWindowKey,
    ValueChanged<String>? onSelectWindow,
    Stream<FounderDashboardSnapshot>? liveSnapshotStream,
    void Function(String jobId, String? orderCode)? onInspectOrder,
    Future<void> Function(DateTime initialDate)? onAddExpenseForDate,
    Future<void> Function(String expenseId, bool paid)? onToggleExpensePaid,
    bool privacyBlurActive = false,
  }) {
    final today = CeoBrazilFiscalCalendar.todayBrasilia();
    final parsedSingleDay =
        CeoBrazilFiscalCalendar.tryParseDayIso(selectedWindowKey);
    final initial = parsedSingleDay ?? today;

    return showModalBottomSheet<FounderCalendarSelectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FounderExecutiveCalendarSheet._(
        key: const ValueKey<String>('ceo-executive-calendar-sheet'),
        isSingleDatePicker: false,
        initialDate: initial,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(today.year + 2, 12, 31),
        snapshot: snapshot,
        liveSnapshotStream: liveSnapshotStream,
        selectedWindowKey: selectedWindowKey,
        onSelectWindow: onSelectWindow,
        onInspectOrder: onInspectOrder,
        onAddExpenseForDate: onAddExpenseForDate,
        onToggleExpensePaid: onToggleExpensePaid,
        privacyBlurActive: privacyBlurActive,
      ),
    );
  }

  /// Abre o seletor executivo de data única e retorna a data escolhida (`null` se cancelado).
  static Future<DateTime?> pickSingleDate(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final normalized = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FounderExecutiveCalendarSheet._(
        key: const ValueKey<String>('ceo-executive-date-picker-sheet'),
        isSingleDatePicker: true,
        initialDate: normalized,
        firstDate: firstDate != null
            ? DateTime(firstDate.year, firstDate.month, firstDate.day)
            : DateTime(2024, 1, 1),
        lastDate: lastDate != null
            ? DateTime(lastDate.year, lastDate.month, lastDate.day)
            : DateTime(normalized.year + 2, 12, 31),
      ),
    );
  }

  @override
  State<FounderExecutiveCalendarSheet> createState() =>
      _FounderExecutiveCalendarSheetState();
}

class _FounderExecutiveCalendarSheetState
    extends State<FounderExecutiveCalendarSheet> {
  final GlobalKey _daySummaryAnchorKey = GlobalKey();
  late final DateTime _todayBrt;
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  late String _activeWindowKey;
  late bool _selectionModeIsSingleDay;
  String? _lastNotifiedWindowKey;
  int _monthSlideDirection = 1;

  @override
  void initState() {
    super.initState();
    _todayBrt = CeoBrazilFiscalCalendar.todayBrasilia();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _activeWindowKey = widget.selectedWindowKey.trim().isEmpty
        ? '30d'
        : widget.selectedWindowKey.trim();
    _lastNotifiedWindowKey = _activeWindowKey;
    _selectionModeIsSingleDay = widget.isSingleDatePicker ||
        CeoBrazilFiscalCalendar.extractSingleDayIsoFromWindowKey(
              _activeWindowKey,
            ) !=
            null;
  }

  bool _isDateEnabled(DateTime day) {
    final minD = widget.firstDate;
    final maxD = widget.lastDate;
    if (minD != null && day.isBefore(minD)) return false;
    if (maxD != null && day.isAfter(maxD)) return false;
    return true;
  }

  void _shiftMonth(int deltaMonths) {
    final target = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + deltaMonths,
      1,
    );
    if (widget.firstDate != null) {
      final minMonth = DateTime(
        widget.firstDate!.year,
        widget.firstDate!.month,
        1,
      );
      if (target.isBefore(minMonth)) return;
    }
    if (widget.lastDate != null) {
      final maxMonth = DateTime(
        widget.lastDate!.year,
        widget.lastDate!.month,
        1,
      );
      if (target.isAfter(maxMonth)) return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _monthSlideDirection = deltaMonths >= 0 ? 1 : -1;
      _displayedMonth = target;
    });
  }

  void _selectSpecificDay(DateTime d) {
    final clean = DateTime(d.year, d.month, d.day);
    if (!_isDateEnabled(clean)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = clean;
      _displayedMonth = DateTime(clean.year, clean.month, 1);
      if (!widget.isSingleDatePicker) {
        _selectionModeIsSingleDay = true;
        _activeWindowKey = 'day:${_toIsoDay(clean)}';
      }
    });
    if (!widget.isSingleDatePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _daySummaryAnchorKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
    }
  }

  DateTime _nextOfficialDasDueDate() {
    final prevMonthYear =
        _todayBrt.month == 1 ? _todayBrt.year - 1 : _todayBrt.year;
    final prevMonth = _todayBrt.month == 1 ? 12 : _todayBrt.month - 1;
    final currentMonthDue = CeoBrazilFiscalCalendar.dasDueDateForCompetence(
      prevMonthYear,
      prevMonth,
    );
    if (!currentMonthDue.isBefore(_todayBrt)) {
      return currentMonthDue;
    }
    return CeoBrazilFiscalCalendar.dasDueDateForCompetence(
      _todayBrt.year,
      _todayBrt.month,
    );
  }

  String _maskOrFormatCents(int cents) {
    if (widget.privacyBlurActive) return 'R\$ ••••';
    return Money.formatBrl(cents);
  }

  void _confirmOverviewSelection() {
    HapticFeedback.lightImpact();
    final effectiveKey = _selectionModeIsSingleDay
        ? 'day:${_toIsoDay(_selectedDate)}'
        : _activeWindowKey;
    final result = FounderCalendarSelectionResult(
      windowKey: effectiveKey,
      isSingleDay: _selectionModeIsSingleDay || effectiveKey == 'today',
      selectedDate: _selectedDate,
    );
    if (_lastNotifiedWindowKey != result.windowKey) {
      _lastNotifiedWindowKey = result.windowKey;
      widget.onSelectWindow?.call(result.windowKey);
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveSnapshotStream != null && !widget.isSingleDatePicker) {
      return StreamBuilder<FounderDashboardSnapshot>(
        stream: widget.liveSnapshotStream,
        initialData: widget.snapshot,
        builder: (context, streamSnap) {
          final liveSnap = streamSnap.data ??
              widget.snapshot ??
              FounderDashboardSnapshot.emptyZero();
          return _buildSheetContainer(context, liveSnap);
        },
      );
    }
    final fallbackSnap =
        widget.snapshot ?? FounderDashboardSnapshot.emptyZero();
    return _buildSheetContainer(context, fallbackSnap);
  }

  Widget _buildSheetContainer(
    BuildContext context,
    FounderDashboardSnapshot liveSnapshot,
  ) {
    final safeBottomFooter = FounderSovereignTokens.modalBottomSafeSpace(
      context,
      extraWhenKeyboardClosed: 14,
      extraWhenKeyboardOpen: 12,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final dailyByIso = <String, FounderDailyMetricPoint>{
      for (final pt in liveSnapshot.dailySeries)
        if (pt.dayIso.trim().isNotEmpty) pt.dayIso.trim(): pt,
    };

    final confirmLabel = _selectionModeIsSingleDay
        ? 'Concluir consulta · ${CeoBrazilFiscalCalendar.formatShortDayPtBr(_selectedDate)}'
        : 'Concluir consulta';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: FounderSovereignTokens.obsidianBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: FounderSovereignTokens.crispBorderStrong),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 34,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Zona 1: Cabeçalho fixo (não rola para fora da tela)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: FounderSovereignTokens.crispBorderStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSheetHeader(context),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: FounderSovereignTokens.crispBorder,
                ),

                // Zona 2: Corpo rolável (atalhos + grade mensal + resumo da data)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (widget.isSingleDatePicker)
                          _buildSingleDateQuickShortcuts()
                        else
                          _buildPeriodAndAgendaShortcuts(liveSnapshot),
                        const SizedBox(height: 12),
                        FounderGlassCard(
                          padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildMonthHeader(),
                              const SizedBox(height: 10),
                              _buildWeekdayHeaderRow(),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve:
                                    const Cubic(0.22, 1.0, 0.36, 1.0),
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin:
                                        Offset(0.06 * _monthSlideDirection, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey<String>(
                                    '${_displayedMonth.year}-${_displayedMonth.month}',
                                  ),
                                  child: _buildMonthGrid(
                                    liveSnapshot,
                                    dailyByIso,
                                  ),
                                ),
                              ),
                              if (!widget.isSingleDatePicker) ...<Widget>[
                                const SizedBox(height: 10),
                                _buildHeatLegend(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.isSingleDatePicker)
                          _buildSingleDateSummaryBox()
                        else
                          Container(
                            key: _daySummaryAnchorKey,
                            child: _buildExecutiveDaySummaryCard(
                              liveSnapshot,
                              dailyByIso,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Zona 3: Rodapé fixo protegido contra barras de navegação Android Edge-to-Edge
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, safeBottomFooter),
                  decoration: const BoxDecoration(
                    color: FounderSovereignTokens.obsidianBackground,
                    border: Border(
                      top: BorderSide(
                        color: FounderSovereignTokens.crispBorder,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    height: 50,
                    child: widget.isSingleDatePicker
                        ? FilledButton.icon(
                            key: const ValueKey<String>(
                              'ceo-date-picker-confirm-btn',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  FounderSovereignTokens.imperialGold,
                              foregroundColor: const Color(0xFF0B0E13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop(_selectedDate);
                            },
                            icon: const FounderPrecisionIcon(
                              FounderIconGlyph.checkValid,
                              size: 17,
                              color: Color(0xFF0B0E13),
                              accentColor: Color(0xFF0B0E13),
                              duotoneAlpha: 0.0,
                            ),
                            label: const Text('Confirmar data'),
                          )
                        : FilledButton.icon(
                            key: const ValueKey<String>(
                              'ceo-calendar-apply-btn',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  FounderSovereignTokens.imperialGold,
                              foregroundColor: const Color(0xFF0B0E13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: _confirmOverviewSelection,
                            icon: const FounderPrecisionIcon(
                              FounderIconGlyph.checkValid,
                              size: 17,
                              color: Color(0xFF0B0E13),
                              accentColor: Color(0xFF0B0E13),
                              duotoneAlpha: 0.0,
                            ),
                            label: Text(
                              confirmLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context) {
    final title = widget.isSingleDatePicker
        ? 'Escolher data'
        : 'Calendário Executivo';
    final subtitle = widget.isSingleDatePicker
        ? 'Selecione o dia exato do lançamento ou vencimento'
        : 'Passado, hoje e datas futuras reais (impostos, mediações e serviços)';

    return Row(
      children: <Widget>[
        const FounderPrecisionBadge(
          FounderIconGlyph.calendarExec,
          boxSize: 40,
          iconSize: 19,
          tintColor: FounderSovereignTokens.imperialGoldBright,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: FounderSovereignTokens.titleStyle(fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FounderSovereignTokens.subtitleStyle(fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Fechar calendário',
          style: IconButton.styleFrom(
            backgroundColor: FounderSovereignTokens.obsidianCard,
            side: const BorderSide(color: FounderSovereignTokens.crispBorder),
            minimumSize: const Size(40, 40),
          ),
          icon: const FounderPrecisionIcon(
            FounderIconGlyph.closeCross,
            color: FounderSovereignTokens.primaryInk,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodAndAgendaShortcuts(FounderDashboardSnapshot snap) {
    final nextDasDate = _nextOfficialDasDueDate();
    final nextDasShort = CeoBrazilFiscalCalendar.formatShortDayPtBr(nextDasDate);

    CeoUnifiedMediationItem? firstOpenMediation;
    for (final m in snap.activeMediations) {
      if (m.isOpen) {
        firstOpenMediation = m;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: _kCalendarWindows.map((choice) {
              final active =
                  !_selectionModeIsSingleDay && _activeWindowKey == choice.key;
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: InkWell(
                  key: ValueKey<String>('ceo-calendar-window-${choice.key}'),
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectionModeIsSingleDay = false;
                      _activeWindowKey = choice.key;
                      if (choice.key == 'today') {
                        _selectedDate = _todayBrt;
                        _displayedMonth =
                            DateTime(_todayBrt.year, _todayBrt.month, 1);
                      }
                    });
                    _lastNotifiedWindowKey = choice.key;
                    widget.onSelectWindow?.call(choice.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? FounderSovereignTokens.imperialGoldSoft
                          : FounderSovereignTokens.obsidianCard,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: active
                            ? FounderSovereignTokens.imperialGold
                            : FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Text(
                      choice.label,
                      style: TextStyle(
                        color: active
                            ? FounderSovereignTokens.imperialGoldBright
                            : FounderSovereignTokens.secondaryInk,
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: <Widget>[
              _QuickAgendaMilestonePill(
                pillKey:
                    const ValueKey<String>('ceo-calendar-jump-next-das-btn'),
                glyph: FounderIconGlyph.taxBankDas,
                label: 'Próximo DAS ($nextDasShort)',
                accent: FounderSovereignTokens.warmAmber,
                active: _selectionModeIsSingleDay &&
                    _isSameCalendarDay(_selectedDate, nextDasDate),
                onTap: () => _selectSpecificDay(nextDasDate),
              ),
              if (firstOpenMediation != null) ...<Widget>[
                const SizedBox(width: 8),
                _QuickAgendaMilestonePill(
                  pillKey: const ValueKey<String>(
                    'ceo-calendar-jump-active-mediation-btn',
                  ),
                  glyph: FounderIconGlyph.mediationBalance,
                  label:
                      'Mediação ativa (${firstOpenMediation.protocolCode})',
                  accent: FounderSovereignTokens.crimsonAlert,
                  active: false,
                  onTap: () {
                    final targetIso = firstOpenMediation!.deadlineDayIso ??
                        firstOpenMediation.openedDayIso;
                    final parsed =
                        CeoBrazilFiscalCalendar.tryParseDayIso(targetIso);
                    if (parsed != null) {
                      _selectSpecificDay(parsed);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleDateQuickShortcuts() {
    final yesterday = DateTime(
      _todayBrt.year,
      _todayBrt.month,
      _todayBrt.day - 1,
    );
    final nextDas = _nextOfficialDasDueDate();

    final shortcuts = <(String, DateTime)>[
      ('Hoje', _todayBrt),
      ('Ontem', yesterday),
      ('Próximo DAS (${CeoBrazilFiscalCalendar.formatShortDayPtBr(nextDas)})', nextDas),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: shortcuts.map((entry) {
          final label = entry.$1;
          final target = entry.$2;
          final active = _isSameCalendarDay(_selectedDate, target);
          final enabled = _isDateEnabled(target);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: enabled ? () => _selectSpecificDay(target) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? FounderSovereignTokens.imperialGoldSoft
                        : FounderSovereignTokens.obsidianCard,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: active
                          ? FounderSovereignTokens.imperialGold
                          : FounderSovereignTokens.crispBorder,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? FounderSovereignTokens.imperialGoldBright
                          : FounderSovereignTokens.secondaryInk,
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthName = _kMonthsPt[(_displayedMonth.month - 1).clamp(0, 11)];
    final isCurrentMonth = _displayedMonth.year == _todayBrt.year &&
        _displayedMonth.month == _todayBrt.month;

    return Row(
      children: <Widget>[
        _MonthNavArrowButton(
          key: const ValueKey<String>('ceo-calendar-prev-month-btn'),
          glyph: FounderIconGlyph.chevronLeft,
          tooltip: 'Mês anterior',
          onTap: () => _shiftMonth(-1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: <Widget>[
              Text(
                '$monthName ${_displayedMonth.year}',
                textAlign: TextAlign.center,
                style: FounderSovereignTokens.titleStyle(fontSize: 15.5),
              ),
              if (!isCurrentMonth && _isDateEnabled(_todayBrt)) ...<Widget>[
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => _selectSpecificDay(_todayBrt),
                  child: const Text(
                    'Voltar para hoje',
                    style: TextStyle(
                      color: FounderSovereignTokens.imperialGoldBright,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MonthNavArrowButton(
          key: const ValueKey<String>('ceo-calendar-next-month-btn'),
          glyph: FounderIconGlyph.chevronRight,
          tooltip: 'Próximo mês',
          onTap: () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaderRow() {
    return Row(
      children: _kWeekdaysShortPt.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: FounderSovereignTokens.eyebrowStyle(
                fontSize: 10.0,
                color: FounderSovereignTokens.mutedInk,
                letterSpacing: 0.45,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildMonthGrid(
    FounderDashboardSnapshot snap,
    Map<String, FounderDailyMetricPoint> dailyByIso,
  ) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final leadingEmpty = (firstOfMonth.weekday - 1).clamp(0, 6);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;
    final rowCount = totalCells ~/ 7;

    final rows = <Widget>[];
    for (var r = 0; r < rowCount; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++) {
        final idx = r * 7 + c;
        final dayNum = idx - leadingEmpty + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 42)));
        } else {
          final date = DateTime(year, month, dayNum);
          cells.add(
            Expanded(
              child: _buildDayCell(date, snap, dailyByIso),
            ),
          );
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(children: cells),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(
    DateTime date,
    FounderDashboardSnapshot snap,
    Map<String, FounderDailyMetricPoint> dailyByIso,
  ) {
    final isSelected = (widget.isSingleDatePicker || _selectionModeIsSingleDay) &&
        _isSameCalendarDay(date, _selectedDate);
    final isPreviewedDay = !isSelected && _isSameCalendarDay(date, _selectedDate);
    final isToday = _isSameCalendarDay(date, _todayBrt);
    final enabled = _isDateEnabled(date);
    final iso = _toIsoDay(date);

    final dots = <Color>[];
    if (!widget.isSingleDatePicker) {
      final agenda = snap.agendaForDay(date, todayBrasilia: _todayBrt);
      final point = dailyByIso[iso];
      final netProfit = point?.netProfitCents ?? agenda.realizedNetProfitCents;
      final completedCount =
          point?.ordersCount ?? agenda.completedOrdersCount;

      if (agenda.hasActiveMediationAlert || (!agenda.isFuture && netProfit < 0)) {
        dots.add(FounderSovereignTokens.crimsonAlert);
      }
      if (!agenda.isFuture && netProfit > 0) {
        dots.add(FounderSovereignTokens.solvencyEmerald);
      }
      if (agenda.hasFiscalOrBillAlert) {
        dots.add(FounderSovereignTokens.warmAmber);
      }
      if (dots.length < 3 &&
          (agenda.hasScheduledOrMaturationActivity ||
              (!agenda.isFuture && completedCount > 0 && netProfit == 0))) {
        dots.add(FounderSovereignTokens.imperialGoldBright);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.28,
        child: InkWell(
          key: ValueKey<String>('ceo-calendar-day-$iso'),
          borderRadius: BorderRadius.circular(11),
          onTap: enabled ? () => _selectSpecificDay(date) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 42,
            decoration: BoxDecoration(
              gradient:
                  isSelected ? FounderSovereignTokens.imperialGoldGradient : null,
              color: isSelected
                  ? null
                  : (isToday
                      ? FounderSovereignTokens.imperialGoldSoft
                      : (isPreviewedDay
                          ? FounderSovereignTokens.obsidianSurface
                          : Colors.transparent)),
              borderRadius: BorderRadius.circular(11),
              border: isSelected
                  ? null
                  : (isToday
                      ? Border.all(
                          color: FounderSovereignTokens.imperialGold
                              .withValues(alpha: 0.65),
                        )
                      : (isPreviewedDay
                          ? Border.all(
                              color: FounderSovereignTokens.crispBorderStrong,
                            )
                          : null)),
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: FounderSovereignTokens.imperialGold
                            .withValues(alpha: 0.26),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0B0E13)
                        : (isToday
                            ? FounderSovereignTokens.imperialGoldBright
                            : (date.isAfter(_todayBrt)
                                ? FounderSovereignTokens.secondaryInk
                                : FounderSovereignTokens.primaryInk)),
                    fontSize: 13.0,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontFeatures: FounderSovereignTokens.tabularFigures,
                  ),
                ),
                const SizedBox(height: 2.5),
                SizedBox(
                  height: 4.5,
                  child: dots.isEmpty
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            for (var i = 0; i < dots.length && i < 3; i++) ...<Widget>[
                              if (i > 0) const SizedBox(width: 2.5),
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF0B0E13)
                                      : dots[i],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatLegend() {
    return Container(
      padding: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const <Widget>[
            _CalendarLegendChip(
              color: FounderSovereignTokens.solvencyEmerald,
              label: 'Lucro',
            ),
            SizedBox(width: 12),
            _CalendarLegendChip(
              color: FounderSovereignTokens.imperialGoldBright,
              label: 'Serviços',
            ),
            SizedBox(width: 12),
            _CalendarLegendChip(
              color: FounderSovereignTokens.warmAmber,
              label: 'Imposto / contas',
            ),
            SizedBox(width: 12),
            _CalendarLegendChip(
              color: FounderSovereignTokens.crimsonAlert,
              label: 'Mediações',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveDaySummaryCard(
    FounderDashboardSnapshot snap,
    Map<String, FounderDailyMetricPoint> dailyByIso,
  ) {
    final iso = _toIsoDay(_selectedDate);
    final agenda = snap.agendaForDay(_selectedDate, todayBrasilia: _todayBrt);
    final events = snap.eventsForDay(_selectedDate);
    final pt = dailyByIso[iso];

    final isFuture = agenda.isFuture;
    final netCents = pt?.netProfitCents ?? agenda.realizedNetProfitCents;
    final ordersCount = pt?.ordersCount ?? agenda.completedOrdersCount;
    final feeCents = pt?.platformRevenueCents ?? 0;
    final gmvCents = pt?.gmvCents ?? agenda.realizedGmvCents;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: FounderGlassCard(
        key: ValueKey<String>('day-summary-$iso-${snap.latestEventSeq}'),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FounderPrecisionIcon(
                      isFuture
                          ? FounderIconGlyph.upcomingEvent
                          : FounderIconGlyph.profitJCurve,
                      size: 16,
                      color: isFuture
                          ? FounderSovereignTokens.warmAmber
                          : FounderSovereignTokens.imperialGoldBright,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _formatFullDayPt(_selectedDate, _todayBrt),
                        style: FounderSovereignTokens.titleStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFuture
                        ? FounderSovereignTokens.warmAmberSoft
                        : FounderSovereignTokens.imperialGoldSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isFuture
                        ? 'AGENDA FUTURA REAL'
                        : (_selectionModeIsSingleDay
                            ? 'DATA SELECIONADA'
                            : 'TOQUE NUM DIA P/ FILTRAR'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: isFuture
                          ? FounderSovereignTokens.warmAmber
                          : FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isFuture)
              _buildResponsiveFourMetrics(
                box1: _DayMiniMetricBox(
                  label: 'Impostos e contas no dia',
                  value: _maskOrFormatCents(agenda.totalPayablesOnDayCents),
                  accent: agenda.totalPayablesOnDayCents > 0
                      ? FounderSovereignTokens.warmAmber
                      : FounderSovereignTokens.secondaryInk,
                ),
                box2: _DayMiniMetricBox(
                  label: 'Serviços agendados',
                  value: '${agenda.scheduledOrdersCount}',
                  suffix:
                      agenda.scheduledOrdersCount == 1 ? 'serviço' : 'serviços',
                  accent: FounderSovereignTokens.imperialGoldBright,
                ),
                box3: _DayMiniMetricBox(
                  label: 'Mediações / prazos',
                  value: '${agenda.mediationsTotalEventsCount}',
                  suffix: agenda.mediationsTotalEventsCount == 1
                      ? 'item'
                      : 'itens',
                  accent: agenda.hasActiveMediationAlert
                      ? FounderSovereignTokens.crimsonAlert
                      : FounderSovereignTokens.secondaryInk,
                ),
                box4: _DayMiniMetricBox(
                  label: 'Liberação a profissionais',
                  value: _maskOrFormatCents(agenda.maturationReleaseCents),
                  accent: agenda.maturationReleaseCents > 0
                      ? FounderSovereignTokens.solvencyEmerald
                      : FounderSovereignTokens.secondaryInk,
                ),
              )
            else
              _buildResponsiveFourMetrics(
                box1: _DayMiniMetricBox(
                  label: 'Seu lucro no dia',
                  value: _maskOrFormatCents(netCents),
                  accent: netCents > 0
                      ? FounderSovereignTokens.solvencyEmerald
                      : (netCents < 0
                          ? FounderSovereignTokens.crimsonAlert
                          : FounderSovereignTokens.primaryInk),
                ),
                box2: _DayMiniMetricBox(
                  label: 'Pedidos no dia',
                  value: '$ordersCount',
                  suffix: agenda.scheduledOrdersCount > 0
                      ? '+${agenda.scheduledOrdersCount} agend.'
                      : (ordersCount == 1 ? 'pedido' : 'pedidos'),
                  accent: FounderSovereignTokens.imperialGoldBright,
                ),
                box3: _DayMiniMetricBox(
                  label: 'Faturamento (13,5%)',
                  value: _maskOrFormatCents(feeCents),
                  accent: FounderSovereignTokens.secondaryInk,
                ),
                box4: _DayMiniMetricBox(
                  label: 'Total movimentado',
                  value: _maskOrFormatCents(gmvCents),
                  accent: FounderSovereignTokens.secondaryInk,
                ),
              ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  isFuture
                      ? 'Nenhum imposto previsto, mediação ativa, conta a pagar ou serviço agendado para esta data até o momento.'
                      : 'Nenhuma movimentação registrada nesta data.',
                  style: FounderSovereignTokens.subtitleStyle(fontSize: 11.5),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    isFuture
                        ? 'Compromissos e agenda real do dia (${events.length})'
                        : 'Movimentações reais registradas no dia (${events.length})',
                    style: const TextStyle(
                      color: FounderSovereignTokens.secondaryInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final ev in events.take(8)) _buildDayEventTile(ev),
                ],
              ),
            if (widget.onAddExpenseForDate != null) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'ceo-calendar-schedule-expense-btn',
                ),
                onPressed: () async {
                  await widget.onAddExpenseForDate!(_selectedDate);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: FounderSovereignTokens.imperialGoldBright,
                  backgroundColor: FounderSovereignTokens.imperialGoldSoft
                      .withValues(alpha: 0.45),
                  side: BorderSide(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.expenseReceipt,
                  size: 16,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                label: Text(
                  isFuture
                      ? 'Agendar conta ou imposto para ${CeoBrazilFiscalCalendar.formatShortDayPtBr(_selectedDate)}'
                      : 'Registrar gasto em ${CeoBrazilFiscalCalendar.formatShortDayPtBr(_selectedDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveFourMetrics({
    required Widget box1,
    required Widget box2,
    required Widget box3,
    required Widget box4,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 255) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              box1,
              const SizedBox(height: 8),
              box2,
              const SizedBox(height: 8),
              box3,
              const SizedBox(height: 8),
              box4,
            ],
          );
        }
        return Column(
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: box1),
                  const SizedBox(width: 8),
                  Expanded(child: box2),
                ],
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: box3),
                  const SizedBox(width: 8),
                  Expanded(child: box4),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayEventTile(CeoCalendarAgendaEvent ev) {
    final accent = _colorForAgendaEvent(ev);
    final glyph = _glyphForAgendaEvent(ev);
    final canOpenOrder = ev.hasLinkedOrder && widget.onInspectOrder != null;
    final canMarkPaid =
        ev.isScheduledExpense && widget.onToggleExpensePaid != null;
    final cleanCode = _humanizeAgendaBadgeLabel(ev);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canOpenOrder
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onInspectOrder!(ev.jobId!, cleanCode);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ev.isMediationOrDispute
                    ? accent.withValues(alpha: 0.45)
                    : FounderSovereignTokens.crispBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: FounderPrecisionIcon(
                    glyph,
                    size: 15.5,
                    color: accent,
                    accentColor: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ev.title,
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ev.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          ev.subtitle,
                          style: const TextStyle(
                            color: FounderSovereignTokens.mutedInk,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ev.grossCents > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 108),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _maskOrFormatCents(ev.grossCents),
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
                if (canMarkPaid) ...<Widget>[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Marcar como pago',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        widget.onToggleExpensePaid!(ev.refId, true),
                    icon: const FounderPrecisionIcon(
                      FounderIconGlyph.checkValid,
                      size: 17,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ] else if (canOpenOrder) ...<Widget>[
                  const SizedBox(width: 4),
                  const FounderPrecisionIcon(
                    FounderIconGlyph.chevronRight,
                    size: 15,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleDateSummaryBox() {
    final dd = _selectedDate.day.toString().padLeft(2, '0');
    final mm = _selectedDate.month.toString().padLeft(2, '0');
    final yyyy = _selectedDate.year.toString().padLeft(4, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Row(
        children: <Widget>[
          const FounderPrecisionIcon(
            FounderIconGlyph.calendarExec,
            size: 17,
            color: FounderSovereignTokens.imperialGoldBright,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatFullDayPt(_selectedDate, _todayBrt),
              style: FounderSovereignTokens.subtitleStyle(
                fontSize: 12.5,
                color: FounderSovereignTokens.primaryInk,
              ),
            ),
          ),
          Text(
            '$dd/$mm/$yyyy',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAgendaMilestonePill extends StatelessWidget {
  const _QuickAgendaMilestonePill({
    required this.pillKey,
    required this.glyph,
    required this.label,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  final Key pillKey;
  final FounderIconGlyph glyph;
  final String label;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: pillKey,
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.22)
              : accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: active ? 0.80 : 0.38),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FounderPrecisionIcon(
              glyph,
              size: 13.5,
              color: accent,
              accentColor: accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavArrowButton extends StatelessWidget {
  const _MonthNavArrowButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onTap,
  });

  final FounderIconGlyph glyph;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FounderSovereignTokens.obsidianSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FounderSovereignTokens.crispBorder),
          ),
          alignment: Alignment.center,
          child: Tooltip(
            message: tooltip,
            child: FounderPrecisionIcon(
              glyph,
              color: FounderSovereignTokens.primaryInk,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegendChip extends StatelessWidget {
  const _CalendarLegendChip({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6.5,
          height: 6.5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: FounderSovereignTokens.subtitleStyle(
            fontSize: 10.8,
            color: FounderSovereignTokens.secondaryInk,
          ),
        ),
      ],
    );
  }
}

class _DayMiniMetricBox extends StatelessWidget {
  const _DayMiniMetricBox({
    required this.label,
    required this.value,
    required this.accent,
    this.suffix,
  });

  final String label;
  final String value;
  final Color accent;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FounderSovereignTokens.subtitleStyle(fontSize: 10.8),
          ),
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 13.5,
                    color: accent,
                  ),
                ),
              ),
              if (suffix != null) ...<Widget>[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    suffix!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.subtitleStyle(
                      fontSize: 10.8,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
