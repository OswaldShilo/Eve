/// What the Home header needs. Real cycle-phase math is out of V0 scope;
/// [phaseBadge] is a per-life-stage label.
class HomeDashboardData {
  const HomeDashboardData({
    required this.greetingName,
    required this.phaseBadge,
    this.lifeStage,
  });

  final String greetingName;
  final String phaseBadge;

  /// Her saved life stage ('cycle' | 'pregnant' | 'conceive' | 'postpartum'
  /// | 'menopause'), or null until she has completed onboarding.
  final String? lifeStage;

  /// Onboarding saves her life stage, so a stored stage means she is done.
  bool get onboardingComplete => lifeStage != null && lifeStage!.isNotEmpty;
}

abstract class HomeRepository {
  Future<HomeDashboardData> loadDashboard(String uid);
}
