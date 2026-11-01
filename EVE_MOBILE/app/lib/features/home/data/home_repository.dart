/// What the Home header needs. Real cycle-phase math is out of V0 scope;
/// [phaseBadge] is a per-life-stage label.
class HomeDashboardData {
  const HomeDashboardData({required this.greetingName, required this.phaseBadge});

  final String greetingName;
  final String phaseBadge;
}

abstract class HomeRepository {
  Future<HomeDashboardData> loadDashboard(String uid);
}
