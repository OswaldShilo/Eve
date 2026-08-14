/// The five life stages selectable on the onboarding Life-Stage screen,
/// as a domain enum. Note this is a *different* representation from
/// `OnboardingState.lifeStage` (a raw `String`, matching the mock's
/// `surveyState` field-for-field per plans/00-design-spec.md §6) — use
/// [lifeStageFromSurveyValue] to convert between the two.
enum LifeStage { cycle, conceive, pregnant, postpartum, perimenopause }

/// Converts the raw onboarding-selector value stored in
/// `OnboardingState.lifeStage` (`'cycle' | 'conceive' | 'pregnant' |
/// 'postpartum' | 'menopause'`) into the domain [LifeStage] enum. Note the
/// one name mismatch: the survey's raw value is `'menopause'`, mapped here
/// to `LifeStage.perimenopause`. Returns `null` for an empty or
/// unrecognized value.
LifeStage? lifeStageFromSurveyValue(String raw) {
  switch (raw) {
    case 'cycle':
      return LifeStage.cycle;
    case 'conceive':
      return LifeStage.conceive;
    case 'pregnant':
      return LifeStage.pregnant;
    case 'postpartum':
      return LifeStage.postpartum;
    case 'menopause':
      return LifeStage.perimenopause;
    default:
      return null;
  }
}

/// The seven modules whose visibility on Home is driven by life stage,
/// per EVE2_PRD.md §5's personalization table.
enum Module {
  cycleOvulationTracking,
  symptomMoodLogging,
  nutritionFitness,
  pregnancyMilestones,
  postpartumRecovery,
  partnerMode,
  doctorSummaryExport,
}

/// Pure, on-device lookup from a stored [LifeStage] to the modules
/// visible on that user's Home dashboard. No backend round-trip needed —
/// per EVE2_PRD.md §10.3, the active module set is computable entirely
/// client-side from `lifeStage`.
///
/// `partnerMode` is marked "Optional" for every life stage in the
/// personalization table: it is never life-stage-gated, only
/// user-consent-gated via `partnerInvite`, so it is returned as
/// always-eligible here and gated by the consuming screen.
List<Module> activeModules(LifeStage stage) {
  switch (stage) {
    case LifeStage.cycle:
      return const [
        Module.cycleOvulationTracking,
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.conceive:
      return const [
        Module.cycleOvulationTracking,
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.pregnant:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.pregnancyMilestones,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.postpartum:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.postpartumRecovery,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.perimenopause:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
  }
}
