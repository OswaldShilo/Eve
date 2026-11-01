import 'row_parsing.dart';

/// Mirrors `PartnerLinkRow`. Table `partner_links`, rowId = primary uid.
/// Read-only on the client — written by the `partnerInvites` function.
class PartnerLink {
  const PartnerLink({
    this.partnerUserId,
    this.relationshipType,
    this.inviteStatus = 'none',
    this.inviteCode,
    this.invitedAt,
    this.linkedAt,
  });

  final String? partnerUserId;
  final String? relationshipType;
  final String inviteStatus; // none | pending | accepted | declined
  final String? inviteCode;
  final DateTime? invitedAt;
  final DateTime? linkedAt;

  factory PartnerLink.fromRow(Map<String, dynamic> data) => PartnerLink(
        partnerUserId: data['partnerUserId'] as String?,
        relationshipType: data['relationshipType'] as String?,
        inviteStatus: (data['inviteStatus'] as String?) ?? 'none',
        inviteCode: data['inviteCode'] as String?,
        invitedAt: parseDateTime(data['invitedAt']),
        linkedAt: parseDateTime(data['linkedAt']),
      );
}
