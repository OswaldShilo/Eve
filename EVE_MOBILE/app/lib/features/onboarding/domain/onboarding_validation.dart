import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';

/// Whether [value] is empty or a plain positive number (the profile's
/// age/height/weight inputs are optional but must be numeric when given).
bool isBlankOrNumber(String value) {
  final v = value.trim();
  if (v.isEmpty) return true;
  final n = num.tryParse(v);
  return n != null && n > 0;
}

/// Whether the survey screen [screenId] has what it needs for her to move
/// on. Only answers the rest of the flow depends on are required: her name
/// (greeting), her life stage (it picks the branch screens) and, once she
/// has chosen to invite a partner, the relationship. Everything else stays
/// optional, as in the mock.
bool canContinueFrom(String screenId, OnboardingState state) {
  switch (screenId) {
    case 'profile':
      return state.name.trim().isNotEmpty &&
          isBlankOrNumber(state.age) &&
          isBlankOrNumber(state.height) &&
          isBlankOrNumber(state.weight);
    case 'lifestage':
      return state.lifeStage != null && state.lifeStage!.isNotEmpty;
    case 'partner-rel':
      return state.partnerRelation.trim().isNotEmpty;
    default:
      return true;
  }
}
