import '../account.dart';

class JsonAccRefreshMeta {
  late AccountType? previousAccountType;
  late bool seenExpiredDialog;

  JsonAccRefreshMeta({
    this.previousAccountType,
    this.seenExpiredDialog = false,
  });

  JsonAccRefreshMeta.fromJson(Map<String, dynamic> json) {
    previousAccountType = accountTypeFromName(json['previousAccountType']);
    seenExpiredDialog = json['seenExpiredDialog'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['previousAccountType'] = previousAccountType?.toSimpleString();
    data['seenExpiredDialog'] = seenExpiredDialog;
    return data;
  }
}
