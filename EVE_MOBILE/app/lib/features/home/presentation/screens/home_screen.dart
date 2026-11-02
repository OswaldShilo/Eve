import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/home/presentation/widgets/bento_card.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class _HeroChip {
  const _HeroChip(this.label, this.emotion, this.message);
  final String label;
  final EveEmotion emotion;
  final String message;
}

const _heroChips = [
  _HeroChip('Standard', EveEmotion.hype, '7-Day Check-in Streak Active'),
  _HeroChip('Support', EveEmotion.caring, 'Rest and recovery recorded.'),
  _HeroChip(
    'Focus',
    EveEmotion.sassy,
    'Late luteal phase: Prioritize restful activities and nutrition.',
  ),
  _HeroChip(
    'Vitality',
    EveEmotion.fertile,
    'Fertile Window: Estimated peak vitality.',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.greetingName = 'Maya',
    this.phaseBadge = 'Follicular Phase • Day 9',
    this.bentoCards = const [
      BentoCardData(
        title: 'Next Cycle Phase',
        value: 'in 14 Days',
        description: 'Regular cycle rhythm',
      ),
      BentoCardData(
        title: 'Check-in Streak',
        value: '8 Days',
        description: 'Daily logging habit',
      ),
      BentoCardData(
        title: 'Daily Recommendation',
        value: 'Boost Collagen & Iron Intake',
        description:
            'Pomegranates and leafy greens are recommended for your current phase.',
        fullWidth: true,
      ),
    ],
    this.heroStandardMessage,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
    this.onNavigateDoctorSummary,
  });

  final String greetingName;
  final String phaseBadge;
  final List<BentoCardData> bentoCards;

  /// Replaces the mock's demo line on the default "Standard" hero chip with
  /// a line built from her real data (the live route sets this).
  final String? heroStandardMessage;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;
  final VoidCallback? onNavigateDoctorSummary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeChipIndex = 0;

  String _messageFor(int index) {
    if (index == 0 && widget.heroStandardMessage != null) {
      return widget.heroStandardMessage!;
    }
    return _heroChips[index].message;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    final activeChip = _heroChips[_activeChipIndex];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            // `.home-header`
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${widget.greetingName}',
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text('Current status overview', style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Container(
                      key: const Key('home-phase-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: eveOutlined(
                        color: EveColors.rubyBlush,
                        radius: 14,
                        borderWidth: 3,
                        shadow: 4,
                      ),
                      child: Text(
                        widget.phaseBadge,
                        textAlign: TextAlign.center,
                        style: text.labelMedium!.copyWith(
                          color: EveColors.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // `.home-hero-card`
            EveCard(
              radius: 24,
              shadow: 6,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  EveCard(
                    color: tokens.soft,
                    radius: 16,
                    borderWidth: 3,
                    shadow: 4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _messageFor(_activeChipIndex),
                        key: const Key('home-hero-speech'),
                        textAlign: TextAlign.center,
                        style: text.titleSmall!.copyWith(color: tokens.ink),
                      ),
                    ),
                  ),
                  // `.mascot-stage-home`
                  SizedBox(
                    width: 210,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          bottom: 6,
                          child: MascotGroundShadow(width: 110, height: 16),
                        ),
                        Positioned(
                          bottom: 14,
                          child: RepaintBoundary(
                            child: EveMascot(
                              emotion: activeChip.emotion,
                              size: 140,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // `.emotion-toggles`
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in _heroChips.asMap().entries) ...[
                          if (entry.key > 0) const SizedBox(width: 6),
                          EveChip(
                            key: Key('home-emotion-chip-${entry.value.label}'),
                            label: entry.value.label,
                            selected: entry.key == _activeChipIndex,
                            onTap: () =>
                                setState(() => _activeChipIndex = entry.key),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // `.bento-grid`: two columns; full-width cards span both.
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final half = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final card in widget.bentoCards)
                      SizedBox(
                        width: card.fullWidth ? constraints.maxWidth : half,
                        child: BentoCard(data: card),
                      ),
                    if (widget.onNavigateDoctorSummary != null)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: BentoCard(
                          key: const Key('home-doctor-summary-button'),
                          data: BentoCardData(
                            title: 'Doctor-Ready Summary',
                            value: 'Create a PDF',
                            description:
                                'A summary of your recent logs to share with your doctor.',
                            fullWidth: true,
                            onTap: widget.onNavigateDoctorSummary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.home,
        onHomeTap: () {
          if (widget.onNavigateHome != null) widget.onNavigateHome!();
        },
        onChatTap: () {
          if (widget.onNavigateChat != null) widget.onNavigateChat!();
        },
        onLogTap: () {
          if (widget.onNavigateLog != null) widget.onNavigateLog!();
        },
      ),
    );
  }
}
