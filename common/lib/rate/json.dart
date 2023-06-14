class JsonRate {
  late DateTime? lastSeen;
  late int? lastRate;

  JsonRate({
    this.lastSeen,
    this.lastRate,
  });

  JsonRate.fromJson(Map<String, dynamic> json) {
    lastSeen = DateTime.tryParse(json['lastSeenRateScreen'] ?? "");
    lastRate = json['lastRate'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['lastSeenRateScreen'] = lastSeen?.toIso8601String();
    data['lastRate'] = lastRate;
    return data;
  }
}
