part of 'rate.dart';

class JsonRate {
  late DateTime? lastSeen;
  late int? lastRate;
  late DateTime? freemiumYoutubeActivatedTime;

  JsonRate({
    this.lastSeen,
    this.lastRate,
    this.freemiumYoutubeActivatedTime,
  });

  JsonRate.fromJson(Map<String, dynamic> json) {
    lastSeen = DateTime.tryParse(json['lastSeenRateScreen'] ?? "");
    lastRate = json['lastRate'];
    freemiumYoutubeActivatedTime = DateTime.tryParse(json['freemiumYoutubeActivatedTime'] ?? "");
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['lastSeenRateScreen'] = lastSeen?.toIso8601String();
    data['lastRate'] = lastRate;
    data['freemiumYoutubeActivatedTime'] = freemiumYoutubeActivatedTime?.toIso8601String();
    return data;
  }

  @override
  String toString() {
    return "JsonRate(lastSeen: $lastSeen, lastRate: $lastRate, freemiumYoutubeActivatedTime: $freemiumYoutubeActivatedTime)";
  }
}
