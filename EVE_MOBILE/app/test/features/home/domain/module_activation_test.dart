import 'package:eve_app/features/home/domain/module_activation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activeModules', () {
    test(
        'cycle (general tracking) returns cycle, symptom, nutrition, '
        'partner, and doctor-summary modules', () {
      expect(
        activeModules(LifeStage.cycle),
        unorderedEquals(<Module>[
          Module.cycleOvulationTracking,
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test('conceive returns the same module set as general tracking', () {
      expect(
        activeModules(LifeStage.conceive),
        unorderedEquals(<Module>[
          Module.cycleOvulationTracking,
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'pregnant excludes cycle tracking and postpartum recovery, '
        'includes pregnancy milestones', () {
      expect(
        activeModules(LifeStage.pregnant),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.pregnancyMilestones,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'postpartum excludes cycle tracking and pregnancy milestones, '
        'includes postpartum recovery', () {
      expect(
        activeModules(LifeStage.postpartum),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.postpartumRecovery,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'perimenopause excludes cycle tracking, pregnancy milestones, '
        'and postpartum recovery', () {
      expect(
        activeModules(LifeStage.perimenopause),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'symptomMoodLogging and doctorSummaryExport are present for every '
        'life stage', () {
      for (final stage in LifeStage.values) {
        expect(activeModules(stage), contains(Module.symptomMoodLogging));
        expect(activeModules(stage), contains(Module.doctorSummaryExport));
      }
    });
  });

  group('lifeStageFromSurveyValue', () {
    test('maps every raw onboarding selector value to its LifeStage', () {
      expect(lifeStageFromSurveyValue('cycle'), LifeStage.cycle);
      expect(lifeStageFromSurveyValue('conceive'), LifeStage.conceive);
      expect(lifeStageFromSurveyValue('pregnant'), LifeStage.pregnant);
      expect(lifeStageFromSurveyValue('postpartum'), LifeStage.postpartum);
      expect(lifeStageFromSurveyValue('menopause'), LifeStage.perimenopause);
    });

    test('returns null for an empty or unrecognized value', () {
      expect(lifeStageFromSurveyValue(''), isNull);
      expect(lifeStageFromSurveyValue('not-a-stage'), isNull);
    });
  });
}
