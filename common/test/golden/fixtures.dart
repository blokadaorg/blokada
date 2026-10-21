import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart' as api;
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

/// Seeds the stores the v6 screens read, so goldens show a realistic state
/// instead of "Please wait...". Values mirror the emulator run.
Future<void> seedCloudAccount(WidgetTester tester) async {
  // The API layer reads the id from AccountId, which AccountStore sets on load.
  await tester.runAsync(() => Core.get<api.AccountId>().change(Markers.testing, 'testaccount01'));
  runInAction(() {
    Core.get<AccountStore>().account = AccountState(
      'testaccount01',
      JsonAccount(
        id: 'testaccount01',
        activeUntil: '2099-01-01T00:00:00Z',
        active: true,
        type: 'cloud',
      ),
    );
  });
}

void seedAppStatus(AppStatus status) {
  runInAction(() => Core.get<AppStore>().status = status);
}

void seedDevice() {
  runInAction(() {
    final device = Core.get<DeviceStore>();
    device.deviceTag = '285d3487ac9';
    device.deviceAlias = 'Pixel';
    device.cloudEnabled = true;
    device.retention = '24h';
  });
}

void seedStats() {
  final now = DateTime(2026, 10, 14, 15).millisecondsSinceEpoch;
  // 24 hourly buckets for the last day.
  final allowed = [3, 1, 0, 0, 0, 0, 1, 4, 6, 5, 4, 3, 5, 6, 4, 3, 5, 6, 7, 5, 4, 3, 2, 3];
  final blocked = [1, 0, 0, 0, 0, 0, 0, 2, 3, 2, 1, 1, 2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 1, 2];
  runInAction(() {
    final stats = Core.get<StatsStore>();
    stats.stats = UiStats(
      totalAllowed: 1840,
      totalBlocked: 412,
      allowedHistogram: allowed,
      blockedHistogram: blocked,
      toplist: [
        UiToplistEntry(null, 'doubleclick.net', true, 14),
        UiToplistEntry(null, 'google-analytics.com', true, 9),
        UiToplistEntry(null, 'apple.com', false, 22),
        UiToplistEntry(null, 'gstatic.com', false, 17),
      ],
      avgDayTotal: 120,
      avgDayAllowed: 90,
      avgDayBlocked: 40,
      latestTimestamp: now,
    );
    stats.hasStats = true;
  });
}
