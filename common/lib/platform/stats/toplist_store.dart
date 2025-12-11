import 'dart:collection';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stats/api.dart' as api;

/// Caches toplist responses to avoid duplicate network calls when data was just fetched.
class ToplistStore with Logging, Actor {
  static const Duration defaultTtl = Duration(hours: 1);

  late final _api = Core.get<api.StatsApi>();
  late final _accountId = Core.get<AccountId>();

  final _cache = HashMap<_ToplistKey, _CachedToplist>();

  @override
  onRegister() {
    Core.register<ToplistStore>(this);
  }

  Future<api.JsonToplistV2Response> fetch({
    required Marker m,
    String? deviceTag,
    String? deviceName,
    int level = 1,
    String? action,
    String? domain,
    int limit = 10,
    String range = "24h",
    String? end,
    String? date,
    Duration ttl = defaultTtl,
    bool force = false,
  }) async {
    if (deviceName == null || deviceName.isEmpty) {
      throw Exception("ToplistStore: deviceName is required for toplist queries");
    }
    final accountId = await _accountId.fetch(m);
    final key = _ToplistKey(
      accountId: accountId,
      deviceTag: deviceTag ?? "",
      deviceName: deviceName ?? "",
      level: level,
      action: action ?? "",
      domain: domain ?? "",
      limit: limit,
      range: range,
      end: end ?? "",
      date: date ?? "",
    );

    if (!force) {
      final cached = _cache[key];
      if (cached != null && DateTime.now().difference(cached.fetchedAt) < ttl) {
        return cached.response;
      }
    }

    final response = await _api.getToplistV2(
      accountId: accountId,
      deviceTag: deviceTag,
      deviceName: deviceName,
      level: level,
      action: action,
      domain: domain,
      limit: limit,
      range: range,
      end: end,
      date: date,
      m: m,
    );

    _cache[key] = _CachedToplist(response, DateTime.now());
    return response;
  }
}

class _CachedToplist {
  final api.JsonToplistV2Response response;
  final DateTime fetchedAt;

  _CachedToplist(this.response, this.fetchedAt);
}

class _ToplistKey {
  final String accountId;
  final String deviceTag;
  final String deviceName;
  final int level;
  final String action;
  final String domain;
  final int limit;
  final String range;
  final String end;
  final String date;

  _ToplistKey({
    required this.accountId,
    required this.deviceTag,
    required this.deviceName,
    required this.level,
    required this.action,
    required this.domain,
    required this.limit,
    required this.range,
    required this.end,
    required this.date,
  });

  @override
  bool operator ==(Object other) {
    return other is _ToplistKey &&
        accountId == other.accountId &&
        deviceTag == other.deviceTag &&
        deviceName == other.deviceName &&
        level == other.level &&
        action == other.action &&
        domain == other.domain &&
        limit == other.limit &&
        range == other.range &&
        end == other.end &&
        date == other.date;
  }

  @override
  int get hashCode => Object.hash(
        accountId,
        deviceTag,
        deviceName,
        level,
        action,
        domain,
        limit,
        range,
        end,
        date,
      );
}
