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

String _toIsoDay(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatFullDayPt(DateTime d, DateTime today) {
  final prefix = _isSameCalendarDay(d, today)
      ? 'Hoje · '
      : '${_kWeekdaysLongPt[(d.weekday - 1).clamp(0, 6)]}, ';
  final monthName = _kMonthsPt[(d.month - 1).clamp(0, 11)].toLowerCase();
  return '$prefix${d.day} de $monthName de ${d.year}';
}

/// Calendário Executivo *Luxo Silencioso* (Obsidiana & Ouro Champagne Acetinado).
///
/// Oferece dois modos de alto padrão:
/// 1. [showExecutiveOverview]: Calendário financeiro interativo com indicadores diários reais
///    de pedidos e lucro líquido (extraídos de `snapshot.dailySeries`) + atalhos de período.
/// 2. [pickSingleDate]: Seletor tátil de data única para lançamento de gastos da empresa,
///    substituindo o seletor padrão do sistema por uma experiência executiva coesa.
class FounderExecutiveCalendarSheet extends StatefulWidget {
  const FounderExecutiveCalendarSheet._({
    super.key,
    required this.isSingleDatePicker,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.snapshot,
    this.selectedWindowKey = '30d',
    this.onSelectWindow,
    this.privacyBlurActive = false,
  });

  final bool isSingleDatePicker;
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final FounderDashboardSnapshot? snapshot;
  final String selectedWindowKey;
  final ValueChanged<String>? onSelectWindow;
  final bool privacyBlurActive;

  /// Abre o Calendário Executivo completo com visão diária real de lucro e pedidos.
  static Future<void> showExecutiveOverview(
    BuildContext context, {
    required FounderDashboardSnapshot snapshot,
    required String selectedWindowKey,
    required ValueChanged<String> onSelectWindow,
    bool privacyBlurActive = false,
  }) {
    final nowBrt = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final today = DateTime(nowBrt.year, nowBrt.month, nowBrt.day);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FounderExecutiveCalendarSheet._(
        key: const ValueKey<String>('ceo-executive-calendar-sheet'),
        isSingleDatePicker: false,
        initialDate: today,
        snapshot: snapshot,
        selectedWindowKey: selectedWindowKey,
        onSelectWindow: onSelectWindow,
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
  late final DateTime _todayBrt;
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  late String _activeWindowKey;
  int _monthSlideDirection = 1;

  late final Map<String, FounderDailyMetricPoint> _dailyByIso;

  @override
  void initState() {
    super.initState();
    final nowBrt = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    _todayBrt = DateTime(nowBrt.year, nowBrt.month, nowBrt.day);
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _activeWindowKey = widget.selectedWindowKey;

    final map = <String, FounderDailyMetricPoint>{};
    final series = widget.snapshot?.dailySeries ?? const <FounderDailyMetricPoint>[];
    for (final pt in series) {
      if (pt.dayIso.trim().isNotEmpty) {
        map[pt.dayIso.trim()] = pt;
      }
    }
    _dailyByIso = map;
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

  void _jumpToDate(DateTime d) {
    final clean = DateTime(d.year, d.month, d.day);
    if (!_isDateEnabled(clean)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = clean;
      _displayedMonth = DateTime(clean.year, clean.month, 1);
    });
  }

  String _maskOrFormatCents(int cents) {
    if (widget.privacyBlurActive) return 'R\$ ••••';
    return Money.formatBrl(cents);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

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
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: FounderSovereignTokens.crispBorderStrong,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSheetHeader(context),
                          const SizedBox(height: 16),
                          if (widget.isSingleDatePicker)
                            _buildSingleDateQuickShortcuts()
                          else
                            _buildPeriodQuickPills(),
                          const SizedBox(height: 16),
                          FounderGlassCard(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _buildMonthHeader(),
                                const SizedBox(height: 14),
                                _buildWeekdayHeaderRow(),
                                const SizedBox(height: 8),
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
                                    child: _buildMonthGrid(),
                                  ),
                                ),
                                if (!widget.isSingleDatePicker) ...<Widget>[
                                  const SizedBox(height: 12),
                                  _buildHeatLegend(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (widget.isSingleDatePicker)
                            _buildSingleDateSummaryBox()
                          else
                            _buildExecutiveDaySummaryCard(),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomInset),
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
                              icon: const Icon(Icons.check_rounded, size: 19),
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
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.check_rounded, size: 19),
                              label: const Text('Concluir consulta'),
                            ),
                    ),
                  ),
                ],
              ),
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
        ? 'Selecione o dia exato do lançamento'
        : 'Toque em qualquer dia para conferir pedidos e lucro';

    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: FounderSovereignTokens.imperialGoldSoft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.42),
            ),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: FounderSovereignTokens.imperialGoldBright,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: FounderSovereignTokens.titleStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: FounderSovereignTokens.subtitleStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Fechar calendário',
          style: IconButton.styleFrom(
            backgroundColor: FounderSovereignTokens.obsidianCard,
            side: const BorderSide(color: FounderSovereignTokens.crispBorder),
            minimumSize: const Size(40, 40),
          ),
          icon: const Icon(
            Icons.close_rounded,
            color: FounderSovereignTokens.primaryInk,
            size: 19,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodQuickPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kCalendarWindows.map((choice) {
          final active = _activeWindowKey == choice.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              key: ValueKey<String>('ceo-calendar-window-${choice.key}'),
              borderRadius: BorderRadius.circular(99),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeWindowKey = choice.key);
                widget.onSelectWindow?.call(choice.key);
                if (choice.key == 'today') {
                  _jumpToDate(_todayBrt);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
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
    );
  }

  Widget _buildSingleDateQuickShortcuts() {
    final yesterday = _todayBrt.subtract(const Duration(days: 1));
    final firstOfMonth = DateTime(_todayBrt.year, _todayBrt.month, 1);

    final shortcuts = <(String, DateTime)>[
      ('Hoje', _todayBrt),
      ('Ontem', yesterday),
      ('Dia 1 deste mês', firstOfMonth),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
                onTap: enabled ? () => _jumpToDate(target) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8.5,
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
          icon: Icons.chevron_left_rounded,
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
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              if (!isCurrentMonth && _isDateEnabled(_todayBrt)) ...<Widget>[
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => _jumpToDate(_todayBrt),
                  child: Text(
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
          icon: Icons.chevron_right_rounded,
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
                fontSize: 10.5,
                color: FounderSovereignTokens.mutedInk,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildMonthGrid() {
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
          cells.add(const Expanded(child: SizedBox(height: 44)));
        } else {
          final date = DateTime(year, month, dayNum);
          cells.add(Expanded(child: _buildDayCell(date)));
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(children: cells),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(DateTime date) {
    final isSelected = _isSameCalendarDay(date, _selectedDate);
    final isToday = _isSameCalendarDay(date, _todayBrt);
    final enabled = _isDateEnabled(date);
    final iso = _toIsoDay(date);
    final point = _dailyByIso[iso];

    Color? dotColor;
    if (point != null) {
      if (point.netProfitCents > 0) {
        dotColor = FounderSovereignTokens.solvencyEmerald;
      } else if (point.ordersCount > 0 || point.gmvCents > 0) {
        dotColor = FounderSovereignTokens.imperialGoldBright;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.28,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => _jumpToDate(date) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? FounderSovereignTokens.imperialGoldGradient
                  : null,
              color: isSelected
                  ? null
                  : (isToday
                      ? FounderSovereignTokens.imperialGoldSoft
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : (isToday
                      ? Border.all(
                          color: FounderSovereignTokens.imperialGold
                              .withValues(alpha: 0.65),
                        )
                      : null),
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: FounderSovereignTokens.imperialGold
                            .withValues(alpha: 0.28),
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
                            : FounderSovereignTokens.primaryInk),
                    fontSize: 13.5,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontFeatures: FounderSovereignTokens.tabularFigures,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor == null
                        ? Colors.transparent
                        : (isSelected
                            ? const Color(0xFF0B0E13)
                            : dotColor),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: const <Widget>[
          _CalendarLegendChip(
            color: FounderSovereignTokens.solvencyEmerald,
            label: 'Dia com lucro líquido',
          ),
          _CalendarLegendChip(
            color: FounderSovereignTokens.imperialGoldBright,
            label: 'Dia com pedidos movimentados',
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveDaySummaryCard() {
    final iso = _toIsoDay(_selectedDate);
    final pt = _dailyByIso[iso];
    final netCents = pt?.netProfitCents ?? 0;
    final ordersCount = pt?.ordersCount ?? 0;
    final feeCents = pt?.platformRevenueCents ?? 0;
    final gmvCents = pt?.gmvCents ?? 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: FounderGlassCard(
        key: ValueKey<String>('day-summary-$iso'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _formatFullDayPt(_selectedDate, _todayBrt),
                    style: FounderSovereignTokens.titleStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _DayMiniMetricBox(
                      label: 'Seu lucro no dia',
                      value: _maskOrFormatCents(netCents),
                      accent: netCents > 0
                          ? FounderSovereignTokens.solvencyEmerald
                          : FounderSovereignTokens.primaryInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayMiniMetricBox(
                      label: 'Pedidos no dia',
                      value: '$ordersCount',
                      suffix: ordersCount == 1 ? 'pedido' : 'pedidos',
                      accent: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _DayMiniMetricBox(
                      label: 'Faturamento (13,5%)',
                      value: _maskOrFormatCents(feeCents),
                      accent: FounderSovereignTokens.secondaryInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayMiniMetricBox(
                      label: 'Total movimentado',
                      value: _maskOrFormatCents(gmvCents),
                      accent: FounderSovereignTokens.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDateSummaryBox() {
    final dd = _selectedDate.day.toString().padLeft(2, '0');
    final mm = _selectedDate.month.toString().padLeft(2, '0');
    final yyyy = _selectedDate.year.toString().padLeft(4, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.event_available_rounded,
            size: 18,
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

class _MonthNavArrowButton extends StatelessWidget {
  const _MonthNavArrowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
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
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              color: FounderSovereignTokens.primaryInk,
              size: 20,
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: FounderSovereignTokens.subtitleStyle(
            fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FounderSovereignTokens.subtitleStyle(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 14.5,
                    color: accent,
                  ),
                ),
              ),
              if (suffix != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  suffix!,
                  style: FounderSovereignTokens.subtitleStyle(
                    fontSize: 11.5,
                    color: FounderSovereignTokens.mutedInk,
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
