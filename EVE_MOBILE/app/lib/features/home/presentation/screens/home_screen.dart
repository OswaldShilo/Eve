import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/home/presentation/widgets/bento_card.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

class _HeroChip {
  const _HeroChip(this.label, this.emotion, this.message);
  final String label;
  final EveEmotion emotion;
  final String message;
}

const _heroChips = [
  _HeroChip('Standard', EveEmotion.hype, '7-Day Check-in Streak Active'),
  _HeroChip('Support', EveEmotion.caring, 'Rest and recovery recorded.'),
  _HeroChip('Focus', EveEmotion.sassy, 'Late luteal phase: Prioritize restful activities and nutrition.'),
  _HeroChip('Vitality', EveEmotion.fertile, 'Fertile Window: Estimated peak vitality.'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.greetingName = 'Maya',
    this.phaseBadge = 'Follicular Phase • Day 9',
    this.bentoCards = const [
      BentoCardData(title: 'Next Cycle Phase', value: 'in 14 Days', description: 'Regular cycle rhythm'),
      BentoCardData(title: 'Check-in Streak', value: '8 Days', description: 'Daily logging habit'),
      BentoCardData(
        title: 'Daily Recommendation',
        value: 'Boost Collagen & Iron Intake',
        description: 'Pomegranates and leafy greens are recommended for your current phase.',
        fullWidth: true,
      ),
    ],
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
  });

  final String greetingName;
  final String phaseBadge;
  final List<BentoCardData> bentoCards;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeChipIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeChip = _heroChips[_activeChipIndex];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back, ${widget.greetingName}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const Text('Current status overview', style: TextStyle(color: Color(0xFF666666))),
                  ],
                ),
                Chip(label: Text(widget.phaseBadge)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(activeChip.message, key: const Key('home-hero-speech'), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  EveMascot(emotion: activeChip.emotion, size: 120),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _heroChips.asMap().entries.map((entry) {
                      final chip = entry.value;
                      return ChoiceChip(
                        key: Key('home-emotion-chip-${chip.label}'),
                        label: Text(chip.label),
                        selected: entry.key == _activeChipIndex,
                        onSelected: (_) => setState(() => _activeChipIndex = entry.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                for (final card in widget.bentoCards.where((c) => !c.fullWidth)) BentoCard(data: card),
              ],
            ),
            const SizedBox(height: 12),
            for (final card in widget.bentoCards.where((c) => c.fullWidth)) BentoCard(data: card),
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
