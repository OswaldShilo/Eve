import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

/// The Log calendar (`#screen-log`): month header with outlined arrows, the
/// `.legend-row` card, a full-month `.calendar-grid` (weekday headers,
/// leading blanks, every day of the month), the selected day's
/// `.log-mascot-toast`, and the `.fab-btn` for a new entry.
///
/// Unlike the mock, where the + button floats over the page, the toast and
/// the button share a row pinned above the bottom nav: the button can never
/// cover the selected day's details, and the calendar scrolls above them.
class LogScreen extends StatefulWidget {
  LogScreen({
    super.key,
    DateTime? month,
    this.monthLabel,
    this.days = const [],
    this.selectedDayIndex = 0,
    this.initialSelectedDay,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
    this.onNewEntry,
  }) : month = month ?? DateTime(2026, 3);

  /// Any date in the month to show.
  final DateTime month;

  /// Defaults to e.g. "March 2026" for [month].
  final String? monthLabel;

  /// Only the days that have logs, in any order.
  final List<CalendarDayData> days;

  /// Legacy initial selection: an index into [days]. Used only when
  /// [initialSelectedDay] is null and [month] is not the current month.
  final int selectedDayIndex;

  /// Day-of-month selected first. Defaults to today in the current month.
  final int? initialSelectedDay;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;
  final VoidCallback? onNewEntry;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late int _selectedDay = _initialDay();

  static const _legend = [
    ('Period', EveColors.rubyMain),
    ('Fertile Window', EveColors.fertileTeal),
    ('Symptom', EveColors.symptomPurple),
    ('Appointment', EveColors.appointmentOrange),
  ];
  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  int _initialDay() {
    if (widget.initialSelectedDay != null) return widget.initialSelectedDay!;
    final now = DateTime.now();
    if (now.year == widget.month.year && now.month == widget.month.month) return now.day;
    if (widget.days.isNotEmpty) {
      final i = widget.selectedDayIndex.clamp(0, widget.days.length - 1);
      return widget.days[i].dayNumber;
    }
    return 1;
  }

  @override
  void didUpdateWidget(covariant LogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year || oldWidget.month.month != widget.month.month) {
      _selectedDay = _initialDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    final year = widget.month.year;
    final month = widget.month.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final leadingBlanks = DateTime(year, month, 1).weekday % 7; // Sunday first
    final byDay = {for (final d in widget.days) d.dayNumber: d};
    final selectedDay = _selectedDay.clamp(1, daysInMonth);
    final selected = byDay[selectedDay];
    final label = widget.monthLabel ?? DateFormat('MMMM yyyy').format(DateTime(year, month));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                children: [
                  // `.log-header`
                  Row(
                    children: [
                      Expanded(child: Text(label, style: text.headlineSmall)),
                      EveIconSquareButton(
                        key: const Key('log-prev-month'),
                        icon: Icons.chevron_left_rounded,
                        semanticLabel: 'Previous month',
                        onPressed: widget.onPreviousMonth,
                      ),
                      const SizedBox(width: 8),
                      EveIconSquareButton(
                        key: const Key('log-next-month'),
                        icon: Icons.chevron_right_rounded,
                        semanticLabel: 'Next month',
                        onPressed: widget.onNextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // `.legend-row`
                  EveCard(
                    key: const Key('log-legend'),
                    radius: 18,
                    shadow: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (final entry in _legend)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: entry.$2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: EveColors.outline, width: 2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // `.legend-item`: 0.74rem, weight 800, ruby-dark.
                              Text(
                                entry.$1,
                                style: text.labelSmall!.copyWith(color: tokens.ink, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // `.calendar-grid`
                  EveCard(
                    key: const Key('log-calendar'),
                    radius: 22,
                    shadow: 6,
                    padding: const EdgeInsets.all(12),
                    child: GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final d in _weekdays)
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(d, style: text.labelMedium!.copyWith(color: EveColors.rubyMain)),
                            ),
                          ),
                        for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                        for (var day = 1; day <= daysInMonth; day++)
                          CalendarDayCell(
                            data: byDay[day] ?? CalendarDayData(dayNumber: day),
                            hasData: byDay.containsKey(day),
                            selected: day == selectedDay,
                            onTap: () => setState(() => _selectedDay = day),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The selected day's toast and the + button share a row pinned
            // above the nav, so the button never covers the day's details.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
              child: Row(
                children: [
                  // `.log-mascot-toast`
                  Expanded(
                    child: EveCard(
                      key: const Key('log-day-toast'),
                      color: tokens.soft,
                      radius: 20,
                      shadow: 5,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: RepaintBoundary(
                              child: EveMascot(emotion: selected?.emotion ?? EveEmotion.neutral, size: 46),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected?.dateTitle ??
                                      DateFormat('MMMM d').format(DateTime(year, month, selectedDay)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall!.copyWith(color: tokens.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selected?.detail ??
                                      (widget.days.isEmpty
                                          ? 'No logs this month yet. Tap + to add how you feel.'
                                          : 'No logs recorded.'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // `.fab-btn` (52px, outlined ruby circle)
                  Semantics(
                    button: true,
                    label: 'New entry',
                    child: GestureDetector(
                      key: const Key('log-fab-new-entry'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onNewEntry?.call(),
                      child: Container(
                        width: 52,
                        height: 52,
                        margin: const EdgeInsets.only(bottom: 6),
                        alignment: Alignment.center,
                        decoration: eveOutlined(color: EveColors.rubyMain, shape: BoxShape.circle, shadow: 6),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.log,
        onHomeTap: () => widget.onNavigateHome?.call(),
        onChatTap: () => widget.onNavigateChat?.call(),
        onLogTap: () => widget.onNavigateLog?.call(),
      ),
    );
  }
}
