import '../account.dart';

class JsonAccRefreshMeta {
  late AccountType? previousAccountType;
  late bool seenExpiredDialog;

  /// When the immediate expiry notification was last shown, ISO-8601.
  ///
  /// Not keyed by the expiry itself: the backend restamps active_until to now
  /// on every repeat webhook for a lapsed account, so a per-expiry key would be
  /// a different value every time. A time floor is what actually dedupes.
  late String? expiryNotifiedAt;

  /// The expiry the OS notification was last scheduled for, ISO-8601.
  ///
  /// The scheduled notification and the immediate one are the same lapse seen
  /// twice, so the immediate path checks this too.
  late String? expiryScheduledFor;

  JsonAccRefreshMeta({
    this.previousAccountType,
    this.seenExpiredDialog = false,
    this.expiryNotifiedAt,
    this.expiryScheduledFor,
  });

  JsonAccRefreshMeta.fromJson(Map<String, dynamic> json) {
    previousAccountType = accountTypeFromName(json['previousAccountType']);
    seenExpiredDialog = json['seenExpiredDialog'] ?? false;
    expiryNotifiedAt = _string(json['expiryNotifiedAt']);
    expiryScheduledFor = _string(json['expiryScheduledFor']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['previousAccountType'] = previousAccountType?.toSimpleString();
    data['seenExpiredDialog'] = seenExpiredDialog;
    data['expiryNotifiedAt'] = expiryNotifiedAt;
    data['expiryScheduledFor'] = expiryScheduledFor;
    return data;
  }

  // Stored metadata predates both timestamps, and a bad value must not brick
  // the guard, so anything that is not a string reads as absent.
  static String? _string(dynamic value) => value is String ? value : null;
}
