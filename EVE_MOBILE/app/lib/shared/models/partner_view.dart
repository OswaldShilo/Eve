import 'row_parsing.dart';

/// Mirrors `PartnerViewRow`. Table `partner_views`, rowId = primary uid.
/// Read-only on every client. A null field means "not shared".
class PartnerView {
  const PartnerView({
    required this.primaryUserId,
    this.approvedCategories = const [],
    this.upcomingAppointmentLabel,
    this.upcomingAppointmentAt,
    this.pregnancyCurrentWeek,
    this.pregnancyLatestMilestone,
    this.supportSuggested,
    this.supportReason,
    this.recentMoodTrend,
    this.recomputedAt,
  });

  final String primaryUserId;
  final List<String> approvedCategories;
  final String? upcomingAppointmentLabel;
  final DateTime? upcomingAppointmentAt;
  final int? pregnancyCurrentWeek;
  final String? pregnancyLatestMilestone;
  final bool? supportSuggested;
  final String? supportReason; // highPain | multipleSymptoms
  final String? recentMoodTrend; // low | neutral | positive
  final DateTime? recomputedAt;

  factory PartnerView.fromRow(Map<String, dynamic> data) => PartnerView(
        primaryUserId: data['primaryUserId'] as String,
        approvedCategories: parseStringList(data['approvedCategories']),
        upcomingAppointmentLabel: data['upcomingAppointmentLabel'] as String?,
        upcomingAppointmentAt: parseDateTime(data['upcomingAppointmentAt']),
        pregnancyCurrentWeek: parseInt(data['pregnancyCurrentWeek']),
        pregnancyLatestMilestone: data['pregnancyLatestMilestone'] as String?,
        supportSuggested: data['supportSuggested'] as bool?,
        supportReason: data['supportReason'] as String?,
        recentMoodTrend: data['recentMoodTrend'] as String?,
        recomputedAt: parseDateTime(data['recomputedAt']),
      );
}
