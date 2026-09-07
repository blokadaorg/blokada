import '../account.dart';

class JsonAccRefreshMeta {
  late AccountType? previousAccountType;
  late bool seenExpiredDialog;

  /// The expiry the immediate notification last announced, ISO-8601.
  ///
  /// Keyed by what was announced rather than when, so one lapse gets one
  /// notification however many times the server dispatches for it, and the
  /// next lapse re-arms itself by carrying a different active_until.
  late String? expiryNotifiedFor;

  /// The expiry the OS notification was last scheduled for, ISO-8601.
  ///
  /// The scheduled notification and the immediate one are the same lapse seen
  /// twice, so the immediate path checks this too.
  late String? expiryScheduledFor;

  JsonAccRefreshMeta({
    this.previousAccountType,
    this.seenExpiredDialog = false,
    this.expiryNotifiedFor,
    this.expiryScheduledFor,
  });

  JsonAccRefreshMeta.fromJson(Map<String, dynamic> json) {
    previousAccountType = accountTypeFromName(json['previousAccountType']);
    seenExpiredDialog = json['seenExpiredDialog'] ?? false;
    expiryNotifiedFor = _string(json['expiryNotifiedFor']);
    expiryScheduledFor = _string(json['expiryScheduledFor']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['previousAccountType'] = previousAccountType?.toSimpleString();
    data['seenExpiredDialog'] = seenExpiredDialog;
    data['expiryNotifiedFor'] = expiryNotifiedFor;
    data['expiryScheduledFor'] = expiryScheduledFor;
    return data;
  }

  // Stored metadata predates both timestamps, and a bad value must not brick
  // the guard, so anything that is not a string reads as absent.
  static String? _string(dynamic value) => value is String ? value : null;
}
