import 'dart:async';
import 'dart:convert';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/api.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockStatsApi extends Mock implements StatsApi {}

class _MockDeviceStore extends Mock implements DeviceStore {}

/// Answers stats requests with [response], recording their params.
class _PendingApi extends Api {
  _PendingApi(this.response);

  final Future<String> response;
  final List<QueryParams> params = [];

  @override
  Future<JsonString> get(ApiEndpoint endpoint, Marker m, {QueryParams? params}) {
    this.params.add(params ?? {});
    return response;
  }
}

JsonStatsEndpoint _endpoint(Map<String, Map<int, double>> byAction) {
  return JsonStatsEndpoint(
    totalAllowed: "0",
    totalBlocked: "0",
    stats: JsonStats(
      metrics: [
        for (final entry in byAction.entries)
          JsonMetrics(
            tags: JsonTags(action: entry.key),
            dps: [
              for (final dp in entry.value.entries) JsonDps(timestamp: dp.key, value: dp.value),
            ],
          ),
      ],
    ),
  );
}

int _day(int day) => DateTime.utc(2026, 11, day).millisecondsSinceEpoch ~/ 1000;

void main() {
  setUpAll(() => registerFallbackValue(Markers.testing));

  group("StatsStore.blockedSince", () {
    test("doesNotReuseThePreviousAccountsTwoWeeks", () async {
      await withTrace((m) async {
        final statsApi = _MockStatsApi();
        final device = _MockDeviceStore();
        final accountId = AccountId();
        Core.register<StatsApi>(statsApi);
        Core.register<DeviceStore>(device);
        Core.register<AccountId>(accountId);
        when(() => device.deviceAlias).thenReturn('Pixel');
        final answers = [
          _endpoint({
            "blocked": {_day(2): 10},
          }),
          _endpoint({
            "blocked": {_day(2): 99},
          }),
        ];
        when(
          () => statsApi.getStats("2w", "24h", 'Pixel', any(), accountId: any(named: 'accountId')),
        ).thenAnswer((_) async => answers.removeAt(0));
        final store = StatsStore();
        final since = DateTime.utc(2026, 11, 1);

        await accountId.change(m, 'first');
        expect(await store.blockedSince(m, since), 10);
        await accountId.change(m, 'second');
        // Within the cache's lifetime, but another account.
        expect(await store.blockedSince(m, since), 99);
      });
    });

    test("asksForTheAccountItCachesUnder", () async {
      await withTrace((m) async {
        final pending = Completer<String>();
        final api = _PendingApi(pending.future);
        final device = _MockDeviceStore();
        final accountId = AccountId();
        Core.register<Api>(api);
        Core.register<StatsApi>(StatsApi());
        Core.register<DeviceStore>(device);
        Core.register<AccountId>(accountId);
        when(() => device.deviceAlias).thenReturn('Pixel');
        final store = StatsStore();

        await accountId.change(m, 'first');
        final read = store.blockedSince(m, DateTime.utc(2026, 11, 1));
        // A switch while the request runs must not send it for 'second'
        // while the result is cached as 'first'.
        await accountId.change(m, 'second');
        pending.complete(jsonEncode(_endpoint({}).toJson()));
        await read;

        expect(api.params.single[ApiParam.accountId], 'first');
      });
    });
  });

  group("sumBlockedSince", () {
    test("countsTheDayOfTheStartAndLaterOnlyBlocked", () {
      final endpoint = _endpoint({
        "blocked": {_day(1): 100, _day(2): 10, _day(3): 20, _day(4): 30},
        "allowed": {_day(2): 500, _day(3): 500},
        "fallthrough": {_day(3): 700},
      });

      // Started mid-day on the 2nd: the whole 2nd counts, the 1st does not.
      final since = DateTime.utc(2026, 11, 2, 15);
      expect(sumBlockedSince(endpoint, since), 60);
    });

    test("acceptsMillisecondTimestamps", () {
      final endpoint = _endpoint({
        "blocked": {_day(1) * 1000: 5, _day(2) * 1000: 7},
      });
      expect(sumBlockedSince(endpoint, DateTime.utc(2026, 11, 2)), 7);
    });

    test("isZeroWithoutData", () {
      expect(sumBlockedSince(_endpoint({}), DateTime.utc(2026, 11, 2)), 0);
    });
  });
}
