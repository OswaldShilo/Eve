import 'row_parsing.dart';

/// Mirrors `PartnerPermissionsRow`. Table `partner_permissions`, rowId = uid.
class PartnerPermissions {
  const PartnerPermissions({this.approvedCategories = const [], this.onlyApproveMode = true});

  /// appointmentReminders | pregnancyMilestones | supportSuggestions | moodUpdates
  final List<String> approvedCategories;
  final bool onlyApproveMode;

  factory PartnerPermissions.fromRow(Map<String, dynamic> data) => PartnerPermissions(
        approvedCategories: parseStringList(data['approvedCategories']),
        onlyApproveMode: (data['onlyApproveMode'] as bool?) ?? true,
      );

  Map<String, dynamic> toRow() => {
        'approvedCategories': approvedCategories,
        'onlyApproveMode': onlyApproveMode,
      };
}
