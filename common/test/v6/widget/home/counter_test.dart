import 'package:common/src/app_variants/v6/widget/home/counter.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/minicard/counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fake_http.dart';
import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

/// Serves the canned responses and counts stats requests; [failStats]
/// makes them fail like a device that is offline.
class _CountingHttp extends FakeHttpChannel {
  int statsRequests = 0;
  bool failStats = false;

  void _count(String url) {
    if (Uri.parse(url).path != '/v2/stats') return;
    statsRequests++;
    if (failStats) throw Exception('offline');
  }

  @override
  Future<String> doGet(String url) {
    _count(url);
    return super.doGet(url);
  }

  @override
  Future<String> doRequest(String url, String? payload, String type) {
    _count(url);
    return super.doRequest(url, payload, type);
  }

  @override
  Future<String> doRequestWithHeaders(
    String url,
    String? payload,
    String type,
    Map<String?, String?> h,
  ) {
    _count(url);
    return super.doRequestWithHeaders(url, payload, type, h);
  }
}

Future<_CountingHttp> _boot(WidgetTester tester, AppStatus status) async {
  await bootModules(tester);
  final http = _CountingHttp();
  Core.di.allowReassignment = true;
  try {
    Core.register<HttpChannel>(http);
  } finally {
    Core.di.allowReassignment = false;
  }
  await seedCloudAccount(tester);
  seedDevice();
  seedAppStatus(status);
  return http;
}

Future<void> _pumpCounter(WidgetTester tester, {bool tickersEnabled = true}) async {
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: Scaffold(
        body: TickerMode(enabled: tickersEnabled, child: const HomeCounter()),
      ),
    ),
  );
}

/// Advances [duration] one second at a time and returns how many of those
/// seconds still had a frame pending afterwards.
Future<int> _idle(WidgetTester tester, Duration duration) async {
  var pending = 0;
  for (var i = 0; i < duration.inSeconds; i++) {
    await tester.pump(const Duration(seconds: 1));
    if (tester.binding.hasScheduledFrame) pending++;
  }
  return pending;
}

void main() {
  testWidgets('shows the blocked count, not blocked plus allowed', (tester) async {
    await _boot(tester, AppStatus.activatedCloud);
    await _pumpCounter(tester);
    await _idle(tester, const Duration(seconds: 3));

    final stats = Core.get<StatsStore>().stats;
    expect(stats.dayBlocked, greaterThan(0));
    expect(stats.dayAllowed, greaterThan(0));
    final counter = tester.widget<MiniCardCounter>(find.byType(MiniCardCounter));
    expect(counter.counter, stats.dayBlocked.toDouble());
    expect(find.text('home counter caption blocked'.i18n), findsOneWidget);
  });

  testWidgets('refreshes every 30 s without drawing frames while idle', (tester) async {
    final http = await _boot(tester, AppStatus.activatedCloud);
    await _pumpCounter(tester);
    // Let the first fetch and the count-up finish.
    await _idle(tester, const Duration(seconds: 3));
    final afterStart = http.statsRequests;
    expect(afterStart, greaterThan(0));

    final pending = await _idle(tester, const Duration(seconds: 120));
    expect(pending, 0, reason: 'idle Home must not keep scheduling frames');
    expect(http.statsRequests - afterStart, 4);
  });

  testWidgets('does not fetch or draw while protection is off', (tester) async {
    final http = await _boot(tester, AppStatus.deactivated);
    await _pumpCounter(tester);

    final pending = await _idle(tester, const Duration(seconds: 120));
    expect(pending, 0);
    expect(http.statsRequests, 0);
  });

  testWidgets('does not fetch while Home is covered', (tester) async {
    final http = await _boot(tester, AppStatus.activatedCloud);
    await _pumpCounter(tester, tickersEnabled: false);

    await _idle(tester, const Duration(seconds: 120));
    expect(http.statsRequests, 0);
  });

  testWidgets('stops when protection turns off and resumes when it turns on', (tester) async {
    final http = await _boot(tester, AppStatus.activatedCloud);
    await _pumpCounter(tester);
    await _idle(tester, const Duration(seconds: 3));

    seedAppStatus(AppStatus.deactivated);
    final afterOff = http.statsRequests;
    await _idle(tester, const Duration(seconds: 90));
    expect(http.statsRequests, afterOff);

    // The first fetch after turning on may be served from the store's cache;
    // the periodic refresh must be running again.
    seedAppStatus(AppStatus.activatedCloud);
    await _idle(tester, const Duration(seconds: 31));
    expect(http.statsRequests, greaterThan(afterOff));
  });

  testWidgets('does not fetch when built while the app is in the background', (tester) async {
    final http = await _boot(tester, AppStatus.activatedCloud);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await _pumpCounter(tester);

    await _idle(tester, const Duration(seconds: 120));
    expect(http.statsRequests, 0);
  });

  testWidgets('a failed fetch shows a retry that loads the count', (tester) async {
    final http = await _boot(tester, AppStatus.activatedCloud);
    http.failStats = true;
    await _pumpCounter(tester);
    await _idle(tester, const Duration(seconds: 3));

    expect(find.byType(MiniCardCounter), findsNothing);
    expect(find.text('universal action try again'.i18n), findsOneWidget);

    http.failStats = false;
    await tester.tap(find.text('universal action try again'.i18n));
    await _idle(tester, const Duration(seconds: 3));

    expect(find.byType(MiniCardCounter), findsOneWidget);
    expect(find.text('home counter caption blocked'.i18n), findsOneWidget);
  });
}
