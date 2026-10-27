import 'dart:io';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fake_http.dart';
import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

/// Serves the same canned responses and remembers which URLs were asked for.
class _RecordingHttpChannel extends FakeHttpChannel {
  final urls = <Uri>[];

  @override
  Future<String> doGet(String url) {
    urls.add(Uri.parse(url));
    return super.doGet(url);
  }

  @override
  Future<String> doRequest(String url, String? payload, String type) {
    urls.add(Uri.parse(url));
    return super.doRequest(url, payload, type);
  }

  @override
  Future<String> doRequestWithHeaders(
      String url, String? payload, String type, Map<String?, String?> h) {
    urls.add(Uri.parse(url));
    return super.doRequestWithHeaders(url, payload, type, h);
  }

  Set<String?> deviceNamesFor(String path) => urls
      .where((it) => it.path == path)
      .map((it) => it.queryParameters['device_name'])
      .toSet();
}

Future<_RecordingHttpChannel> _pump(WidgetTester tester, DomainDetailSection section) async {
  // Tall enough that the whole ListView is built.
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The favicon's image cache asks for a directory.
  final dir = Directory.systemTemp.createTempSync("domain_detail");
  const pathProvider = MethodChannel("plugins.flutter.io/path_provider");
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProvider, (_) async => dir.path);
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    dir.deleteSync(recursive: true);
  });

  await bootModules(tester);
  await seedCloudAccount(tester);
  seedDevice(); // This device is "Pixel".
  final http = _RecordingHttpChannel();
  Core.di.allowReassignment = true;
  try {
    Core.register<HttpChannel>(http);
  } finally {
    Core.di.allowReassignment = false;
  }

  await tester.pumpWidget(BlokadaApp(isFamily: false, content: Scaffold(body: section)));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  return http;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

UiJournalMainEntry _entry() => UiJournalMainEntry(
      domainName: "ads.example.com",
      requests: 1,
      action: UiJournalAction.block,
      listId: "",
    );

void main() {
  testWidgets("an entry from another device shows that device and counts its requests",
      (tester) async {
    final http = await _pump(
      tester,
      DomainDetailSection(
        entry: _entry(),
        level: 2,
        domain: "ads.example.com",
        fetchToplist: false,
        deviceName: "Living Room Router",
      ),
    );

    expect(http.deviceNamesFor("/v2/stats"), {"Living Room Router"});
    expect(find.text("universal label device".i18n), findsOneWidget);
    expect(find.text("Living Room Router"), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets("subdomains and recent activity come from the entry's device", (tester) async {
    final http = await _pump(
      tester,
      DomainDetailSection(
        entry: _entry(),
        level: 2,
        domain: "example.com",
        deviceName: "Living Room Router",
      ),
    );

    expect(http.deviceNamesFor("/v2/activity/toplist"), {"Living Room Router"});
    expect(http.deviceNamesFor("/v2/activity"), {"Living Room Router"});

    await _unmount(tester);
  });

  testWidgets("without a device name the screen shows this device", (tester) async {
    final http = await _pump(
      tester,
      DomainDetailSection(
        entry: _entry(),
        level: 2,
        domain: "ads.example.com",
        fetchToplist: false,
      ),
    );

    expect(http.deviceNamesFor("/v2/stats"), {"Pixel"});
    expect(find.text("Pixel"), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets("an entry without a device name is not counted as this device", (tester) async {
    final http = await _pump(
      tester,
      DomainDetailSection(
        entry: _entry(),
        level: 2,
        domain: "ads.example.com",
        fetchToplist: false,
        deviceName: "",
      ),
    );

    expect(http.deviceNamesFor("/v2/stats"), isEmpty);
    expect(find.text("universal label device".i18n), findsNothing);
    expect(find.text("Pixel"), findsNothing);

    await _unmount(tester);
  });
}
