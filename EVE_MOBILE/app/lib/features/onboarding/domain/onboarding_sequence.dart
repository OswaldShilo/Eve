import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';

const _basePrefix = ['auth', 'profile', 'lifestage'];

List<String> onboardingSequence(OnboardingState state) {
  final List<String> branchScreens;
  switch (state.lifeStage) {
    case 'cycle':
      branchScreens = ['cycle-info', 'cycle-symptoms', 'cycle-goals'];
      break;
    case 'pregnant':
      branchScreens = ['pregnant-due', 'pregnant-meds', 'pregnant-symptoms'];
      break;
    default:
      branchScreens = ['simplified-branch'];
  }

  final commonScreens = <String>['food', 'workout', 'notifications', 'ai-scope', 'partner-ask'];
  if (state.partnerInvite) {
    commonScreens.addAll(['partner-rel', 'partner-perm']);
  }
  commonScreens.addAll(['theme', 'completion']);

  return [..._basePrefix, ...branchScreens, ...commonScreens];
}

String routeForScreen(String screenId) => '/onboarding/$screenId';
