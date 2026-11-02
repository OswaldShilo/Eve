import 'package:flutter/foundation.dart';

import '../domain/module_activation.dart';
import 'widgets/bento_card.dart';

/// Builds the Home bento cards for her life stage from [activeModules].
///
/// Only modules with a real data source show a value: the symptom & mood
/// log (her own entries this month) and the partner chat / doctor summary
/// entry points. Modules whose engines are not built yet (cycle phase
/// prediction, nutrition & fitness suggestions, pregnancy milestones,
/// postpartum recovery) render as clearly-labelled "Coming soon"
/// placeholders, never as invented numbers.
///
/// The doctor summary is not included here; Home shows it as its own
/// full-width entry card.
List<BentoCardData> moduleCardsFor(
  String? lifeStageValue, {
  required int? logsThisMonth,
  VoidCallback? onOpenLog,
  VoidCallback? onOpenChat,
}) {
  final stage = lifeStageFromSurveyValue(lifeStageValue ?? '');
  if (stage == null) return const [];

  final cards = <BentoCardData>[];
  for (final module in activeModules(stage)) {
    switch (module) {
      case Module.cycleOvulationTracking:
        cards.add(
          const BentoCardData(
            title: 'Next Cycle Phase',
            value: '',
            description:
                'Phase predictions will appear here as you log your cycle.',
            placeholder: true,
          ),
        );
      case Module.symptomMoodLogging:
        final count = logsThisMonth;
        cards.add(
          BentoCardData(
            title: 'Check-ins',
            value: count == null
                ? '…'
                : count == 1
                ? '1 this month'
                : '$count this month',
            description: count == 0
                ? 'Tap to log how you feel today.'
                : 'Symptom and mood entries',
            onTap: onOpenLog,
          ),
        );
      case Module.nutritionFitness:
        cards.add(
          const BentoCardData(
            title: 'Daily Recommendation',
            value: '',
            description:
                'Food and movement suggestions for your stage are on the way.',
            placeholder: true,
          ),
        );
      case Module.pregnancyMilestones:
        cards.add(
          const BentoCardData(
            title: 'Pregnancy Milestones',
            value: '',
            description: 'Week-by-week milestones will appear here.',
            placeholder: true,
          ),
        );
      case Module.postpartumRecovery:
        cards.add(
          const BentoCardData(
            title: 'Postpartum Recovery',
            value: '',
            description: 'Recovery tracking will appear here.',
            placeholder: true,
          ),
        );
      case Module.partnerMode:
        if (onOpenChat != null) {
          cards.add(
            BentoCardData(
              title: 'Partner Chat',
              value: 'Open chat',
              description: 'Talk with your partner, with Eve’s gentle nudges.',
              onTap: onOpenChat,
            ),
          );
        }
      case Module.doctorSummaryExport:
        break; // rendered by HomeScreen as its own entry card
    }
  }
  return cards;
}
