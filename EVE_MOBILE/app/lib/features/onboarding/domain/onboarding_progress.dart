double onboardingProgressPercent({required int currentIndex, required int totalScreens}) {
  final raw = ((currentIndex + 1) / totalScreens * 100).round();
  return raw.clamp(10, 100).toDouble();
}
