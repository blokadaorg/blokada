import 'dart:convert';
import 'dart:io';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/funnel/domain/funnel.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

class _FakeAppStore extends Fake implements AppStore {
  final _listeners = <Function(Marker)>[];

  @override
  AppStatus status = AppStatus.unknown;

  @override
  addOn<T>(EmitterEvent<T> on, Function(Marker) listener) {
    expect(on, appStatusChanged);
    _listeners.add(listener);
  }

  Future<void> emitStatus(AppStatus next) async {
    status = next;
    for (final l in _listeners) {
      await l(Markers.testing);
    }
  }
}

class _RecordingTransport implements FunnelTransport {
  final List<String> urls = [];
  final List<Map<String, dynamic>> bodies = [];
  Object? failWith;

  List<String> get events => bodies.map((b) => b["event"] as String).toList();

  @override
  Future<void> post(String url, String body) async {
    urls.add(url);
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    if (failWith != null) throw failWith!;
  }
}

Future<_RecordingTransport> _setUp({
  Flavor flavor = Flavor.v6,
  PlatformType platform = PlatformType.iOS,
}) async {
  Core.act = ActScreenplay(ActScenario.test, flavor, platform);
  await CoreModule().create();
  Core.register<BaseUrl>(BaseUrl());
  final env = EnvActor()..appVersion = "26.11.1219";
  Core.register<EnvActor>(env);
  Core.register<CurrentModalValue>(CurrentModalValue());
  Core.register<FunnelSentValue>(FunnelSentValue());
  final transport = _RecordingTransport();
  Core.register<FunnelTransport>(transport);
  return transport;
}

void main() {
  group('FunnelActor', () {
    test('sends only the four allowed fields to the api', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        await FunnelActor(enabled: true).send(m, FunnelEvent.pulseOpenedHome);

        expect(transport.urls, ["https://api.blocka.net/v2/funnel"]);
        expect(transport.bodies.single, {
          "event": "pulse_opened_home",
          "flavor": "six",
          "platform": "ios",
          "app_version": "26.11.1219",
        });
      });
    });

    test('maps family on android', () async {
      await withTrace((m) async {
        final transport = await _setUp(flavor: Flavor.family, platform: PlatformType.android);
        await FunnelActor(enabled: true).send(m, FunnelEvent.onboardingFamilyHome);

        expect(transport.urls, ["https://family.api.blocka.net/v2/funnel"]);
        expect(transport.bodies.single["flavor"], "family");
        expect(transport.bodies.single["platform"], "android");
      });
    });

    test('counts onboarding and setup once per install', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        final actor = FunnelActor(enabled: true);
        await actor.send(m, FunnelEvent.setupStarted);
        await actor.send(m, FunnelEvent.setupStarted);
        await Future.wait([
          actor.send(m, FunnelEvent.onboardingDns),
          actor.send(m, FunnelEvent.onboardingDns),
        ]);
        expect(transport.events, ["setup_started", "onboarding_dns"]);

        // A later start of the app reads the flag back.
        await FunnelActor(enabled: true).send(m, FunnelEvent.setupStarted);
        expect(transport.events, ["setup_started", "onboarding_dns"]);
      });
    });

    test('counts every Privacy Pulse open', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        final actor = FunnelActor(enabled: true);
        await actor.send(m, FunnelEvent.pulseOpenedHome);
        await actor.send(m, FunnelEvent.pulseOpenedHome);
        await actor.send(m, FunnelEvent.pulseOpenedPush);
        expect(transport.events, ["pulse_opened_home", "pulse_opened_home", "pulse_opened_push"]);
      });
    });

    test('sends setup complete only after a first-run screen', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        final actor = FunnelActor(enabled: true);

        // Set up before this version: never saw the intro.
        await actor.send(m, FunnelEvent.onboardingDns);
        await actor.send(m, FunnelEvent.setupComplete);
        expect(transport.events, ["onboarding_dns"]);

        await actor.send(m, FunnelEvent.onboardingIntro);
        await actor.send(m, FunnelEvent.setupComplete);
        await actor.send(m, FunnelEvent.setupComplete);
        expect(transport.events, ["onboarding_dns", "onboarding_intro", "setup_complete"]);
      });
    });

    test('a failed send neither throws nor retries', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        transport.failWith = HttpCodeException(500, "boom");
        final actor = FunnelActor(enabled: true);
        await actor.send(m, FunnelEvent.onboardingIntro);
        await actor.send(m, FunnelEvent.onboardingIntro);
        await actor.send(m, FunnelEvent.pulseOpenedHome);
        expect(transport.events, ["onboarding_intro", "pulse_opened_home"]);
      });
    });

    test('sends nothing when disabled', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        final actor = FunnelActor(enabled: false);
        await actor.send(m, FunnelEvent.onboardingIntro);
        await actor.send(m, FunnelEvent.pulseOpenedHome);
        expect(transport.bodies, isEmpty);
      });
    });

    test('funnelSignal sends through the registered actor', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        Core.register<FunnelActor>(FunnelActor(enabled: true));
        funnelSignal(m, FunnelEvent.pulseOpenedHome);
        await Future<void>.delayed(Duration.zero);
        expect(transport.events, ["pulse_opened_home"]);
      });
    });

    test('funnelSignal is a no-op without the actor', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        funnelSignal(m, FunnelEvent.pulseOpenedHome);
        await Future<void>.delayed(Duration.zero);
        expect(transport.events, isEmpty);
      });
    });

    test('debug and test builds are disabled by default', () async {
      await withTrace((m) async {
        await _setUp();
        expect(FunnelActor().enabled, isFalse);
      });
    });

    test('counts the setup sheets when they open', () async {
      await withTrace((m) async {
        // Family: setup complete comes from its phase, not AppStore.
        final transport = await _setUp(flavor: Flavor.family);
        await FunnelActor(enabled: true).onStart(m);

        final modal = Core.get<CurrentModalValue>();
        await modal.change(m, Modal.onboardPrivateDns);
        await modal.change(m, null);
        await modal.change(m, Modal.onboardSafari);
        await modal.change(m, Modal.support);
        await Future<void>.delayed(Duration.zero);

        expect(transport.events, ["onboarding_dns", "onboarding_safari"]);
      });
    });
  });

  group('FunnelActor on Blokada 6', () {
    test('sends setup complete once protection is on', () async {
      await withTrace((m) async {
        final transport = await _setUp();
        final app = _FakeAppStore();
        Core.register<AppStore>(app);
        final actor = FunnelActor(enabled: true);
        await actor.onStart(m);

        await actor.send(m, FunnelEvent.onboardingIntro);
        await app.emitStatus(AppStatus.deactivated);
        await app.emitStatus(AppStatus.activatedCloud);
        await app.emitStatus(AppStatus.deactivated);
        await app.emitStatus(AppStatus.activatedPlus);

        expect(transport.events, ["onboarding_intro", "setup_complete"]);
      });
    });
  });

  group('DirectFunnelTransport', () {
    test('sends no user agent or other identifying header', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final headers = <String, List<String>>{};
      String? body;
      server.listen((req) async {
        req.headers.forEach((name, values) => headers[name] = values);
        body = await utf8.decodeStream(req);
        req.response.statusCode = 200;
        await req.response.close();
      });

      await DirectFunnelTransport().post(
        "http://127.0.0.1:${server.port}/v2/funnel",
        '{"event":"x"}',
      );

      expect(body, '{"event":"x"}');
      expect(headers.keys.toSet(), {"host", "content-type", "content-length", "accept-encoding"});
    });

    test('throws on a non-200 answer', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        await req.drain<void>();
        req.response.statusCode = 400;
        await req.response.close();
      });

      await expectLater(
        DirectFunnelTransport().post("http://127.0.0.1:${server.port}/v2/funnel", "{}"),
        throwsA(isA<HttpCodeException>()),
      );
    });
  });

  group('FunnelSentValue', () {
    test('round trips the sent events', () {
      final value = FunnelSentValue();
      expect(value.fromStringified(value.toStringified({"b", "a"})), {"a", "b"});
      expect(value.fromStringified(""), isEmpty);
    });
  });
}
