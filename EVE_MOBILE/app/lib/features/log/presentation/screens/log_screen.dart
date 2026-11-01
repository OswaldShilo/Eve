import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({
    super.key,
    this.monthLabel = 'March 2026',
    this.days = const [],
    this.selectedDayIndex = 0,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
    this.onNewEntry,
  });

  final String monthLabel;
  final List<CalendarDayData> days;
  final int selectedDayIndex;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;
  final VoidCallback? onNewEntry;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late int _selectedIndex = widget.selectedDayIndex;

  static const _legend = [
    ('Period', Color(0xFFFF2A6D)),
    ('Fertile Window', Color(0xFF2EC4B6)),
    ('Symptom', Color(0xFF9B51E0)),
    ('Appointment', Color(0xFFFF9F1C)),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedDay = widget.days.isEmpty ? null : widget.days[_selectedIndex];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.monthLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const Row(children: [Icon(Icons.chevron_left), Icon(Icons.chevron_right)]),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final entry in _legend)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.$2, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(entry.$1, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < widget.days.length; i++)
                      CalendarDayCell(
                        data: widget.days[i],
                        selected: i == _selectedIndex,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                  ],
                ),
                if (selectedDay != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        EveMascot(emotion: selectedDay.emotion, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedDay.dateTitle ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(selectedDay.detail ?? 'No logs recorded.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                key: const Key('log-fab-new-entry'),
                onPressed: () => widget.onNewEntry?.call(),
                child: const Icon(Icons.add),
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
