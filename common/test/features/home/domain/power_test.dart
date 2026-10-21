import 'package:common/src/core/core.dart';
import 'package:common/src/features/home/domain/power.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

/// App status with the emitter the actor listens to.
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

/// Plays a scripted status sequence for each toggle, like AppStartStore does.
class _FakeAppStartStore extends Fake implements AppStartStore {
  _FakeAppStartStore(this.app);

  final _FakeAppStore app;
  List<AppStatus> onToggle = [];
  bool throwOnboarding = false;
  Object? throwOther;
  final toggles = <Duration?>[];

  @override
  Future<void> toggleApp(Marker m, {Duration? duration}) async {
    toggles.add(duration);
    for (final s in onToggle) {
      await app.emitStatus(s);
    }
    if (throwOnboarding) throw OnboardingException();
    if (throwOther != null) throw throwOther!;
  }
}

void main() {
  group('PowerActor', () {
    late _FakeAppStore app;
    late _FakeAppStartStore appStart;
    late CurrentModalValue modal;
    late DateTime now;
    late PowerActor actor;
    late int confirmed;

    Future<void> setUp(Marker m) async {
      app = _FakeAppStore();
      appStart = _FakeAppStartStore(app);
      modal = CurrentModalValue();
      now = DateTime(2026, 1, 1, 12);
      Core.register<AppStore>(app);
      Core.register<AppStartStore>(appStart);
      Core.register<CurrentModalValue>(modal);

      actor = PowerActor(now: () => now);
      actor.create(m);
      confirmed = 0;
      actor.onProtectionConfirmed.listen((_) => confirmed++);
    }

    // Stream events are delivered asynchronously.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('fires once when the user switches protection on', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.activatedCloud];
        await actor.toggle(m);
        await settle();
        expect(confirmed, 1);

        // Later updates while on (Plus coming up, a reconnect) are not new activations.
        await app.emitStatus(AppStatus.activatedPlus);
        await app.emitStatus(AppStatus.reconfiguring);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 1);
      });
    });

    test('does not fire on app start', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.initializing);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('does not fire on a reconnect', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.activatedCloud);
        await app.emitStatus(AppStatus.reconfiguring);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('fires once for each separate activation', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.activatedCloud];
        await actor.toggle(m);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.paused];
        await actor.pause(m, const Duration(minutes: 5));
        expect(appStart.toggles.last, const Duration(minutes: 5));

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.activatedCloud];
        await actor.toggle(m);
        await settle();
        expect(confirmed, 2);
      });
    });

    test('switching freemium off does not fire', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.activatedFreemium);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.deactivated];
        await actor.toggle(m);
        // Protection coming back on its own is not the user's activation.
        await app.emitStatus(AppStatus.activatedFreemium);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('a failed activation does not fire', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.paused];
        await actor.toggle(m);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('a toggle that throws leaves no pending activation', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.throwOther = Exception('toggle failed');
        await expectLater(actor.toggle(m), throwsException);

        // Protection coming up another way must not be credited to the failed tap.
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('an activation through DNS onboarding fires once it completes', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.paused];
        appStart.throwOnboarding = true;
        await actor.toggle(m);
        expect(modal.present, Modal.onboardPrivateDns);

        // The DNS profile is installed and the app starts itself.
        now = now.add(const Duration(minutes: 2));
        await app.emitStatus(AppStatus.reconfiguring);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 1);
      });
    });

    test('protection coming up after the window does not fire', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.paused];
        appStart.throwOnboarding = true;
        await actor.toggle(m);

        now = now.add(PowerActor.confirmWindow + const Duration(seconds: 1));
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);

        // The stale request is gone, so it cannot fire later either.
        await app.emitStatus(AppStatus.reconfiguring);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);
      });
    });

    test('pausing cancels a pending activation', () async {
      await withTrace((m) async {
        await setUp(m);
        await app.emitStatus(AppStatus.deactivated);

        appStart.onToggle = [AppStatus.reconfiguring, AppStatus.paused];
        appStart.throwOnboarding = true;
        await actor.toggle(m);

        appStart.throwOnboarding = false;
        appStart.onToggle = [];
        await actor.pause(m, null);
        await app.emitStatus(AppStatus.activatedCloud);
        await settle();
        expect(confirmed, 0);
      });
    });
  });
}
