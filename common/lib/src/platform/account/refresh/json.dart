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

  JsonAccRefreshMeta({
    this.previousAccountType,
    this.seenExpiredDialog = false,
    this.expiryNotifiedFor,
  });

  JsonAccRefreshMeta.fromJson(Map<String, dynamic> json) {
    previousAccountType = accountTypeFromName(json['previousAccountType']);
    seenExpiredDialog = json['seenExpiredDialog'] ?? false;
    expiryNotifiedFor = _string(json['expiryNotifiedFor']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['previousAccountType'] = previousAccountType?.toSimpleString();
    data['seenExpiredDialog'] = seenExpiredDialog;
    data['expiryNotifiedFor'] = expiryNotifiedFor;
    return data;
  }

  // Stored metadata predates this timestamp, and a bad value must not brick
  // the guard, so anything that is not a string reads as absent.
  static String? _string(dynamic value) => value is String ? value : null;
}
