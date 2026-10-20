import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/app/start/start.dart';

/// Length of the timed pause the power button's countdown arc is scaled to.
const _pauseArcSeconds = 300.0;

/// Whether the countdown replaces the power icon: only a timed pause that
/// still has time left has a countdown to show.
bool shouldShowPauseTimer(AppStatus status, int remainingSeconds) {
  return status.isInactive() && remainingSeconds > 0;
}

/// What a tap on the power button does.
enum PowerTap {
  /// Status is still resolving; a second toggle would race the first.
  none,

  /// Switch protection on, or off where there is nothing to pause (freemium).
  toggle,

  /// Ask how long to pause: active paid protection never goes off on one tap.
  pauseSheet,
}

/// Everything the power button draws and does, derived from app state alone,
/// so the widget holds no rules of its own and the mapping can be tested.
class PowerButtonState {
  /// Protection is still resolving: the spinner shows and taps are ignored.
  final bool working;

  /// Protection is on: the blue ring and the filled cover show.
  final bool active;

  /// The orange ring shows over the blue one (Plus with the VPN on).
  final bool plus;

  /// The ring uses the freemium colours (Safari-only protection).
  final bool freemium;

  /// Seconds left of a timed pause; the countdown replaces the icon. Null
  /// when there is no timed pause.
  final int? pauseSecondsLeft;

  final PowerTap tap;
  final PowerTap longTap;

  const PowerButtonState({
    required this.working,
    required this.active,
    required this.plus,
    required this.freemium,
    required this.pauseSecondsLeft,
    required this.tap,
    required this.longTap,
  });

  /// The button looks pushed in (white cover) while on or switching.
  bool get pressed => active || working;

  /// Protection is off and settled; the icon draws dark on the bare button.
  bool get inactive => !active && !working;

  /// How much of the pause arc is used up (1.0 hides it, as with no pause).
  double get pauseArc =>
      pauseSecondsLeft == null ? 1.0 : 1 - (pauseSecondsLeft! / _pauseArcSeconds);

  @override
  bool operator ==(Object other) =>
      other is PowerButtonState &&
      other.working == working &&
      other.active == active &&
      other.plus == plus &&
      other.freemium == freemium &&
      other.pauseSecondsLeft == pauseSecondsLeft &&
      other.tap == tap &&
      other.longTap == longTap;

  @override
  int get hashCode => Object.hash(working, active, plus, freemium, pauseSecondsLeft, tap, longTap);

  @override
  String toString() =>
      'PowerButtonState(working: $working, active: $active, plus: $plus, '
      'freemium: $freemium, pauseSecondsLeft: $pauseSecondsLeft, tap: $tap, longTap: $longTap)';
}

/// Maps app state to what the power button shows and what a tap does.
///
/// [pauseSecondsLeft] is the time left of a timed pause (0 when none).
/// The account type reaches the button only through [status] (cloud versus
/// plus) and [isFreemium].
PowerButtonState powerButtonState({
  required AppStatus status,
  required bool isFreemium,
  required int pauseSecondsLeft,
}) {
  final working = status.isWorking();
  final active = status.isActive();

  final PowerTap tap;
  if (working) {
    tap = PowerTap.none;
  } else if (active && !isFreemium) {
    tap = PowerTap.pauseSheet;
  } else {
    tap = PowerTap.toggle;
  }

  return PowerButtonState(
    working: working,
    active: active,
    plus: status == AppStatus.activatedPlus,
    freemium: isFreemium,
    pauseSecondsLeft: shouldShowPauseTimer(status, pauseSecondsLeft) ? pauseSecondsLeft : null,
    tap: tap,
    // A long press skips the pause sheet and toggles straight away.
    longTap: working ? PowerTap.none : PowerTap.toggle,
  );
}

/// Runs the power button's actions and tells the UI when protection the user
/// switched on is confirmed running.
///
/// "Confirmed" used to be a flag the button set when its own spinner stopped,
/// which also fired on app start and on every reconnect. Here it comes from
/// app state: it fires once, on the first active status after the user asked
/// to switch protection on. An activation that detours through DNS onboarding
/// or the paywall still confirms when it completes, within [confirmWindow].
class PowerActor with Logging, Actor {
  /// How long a switch-on request waits for protection to come up. Long
  /// enough for the DNS profile install, short enough that protection coming
  /// up much later (another device, a restore) is not credited to the tap.
  static const confirmWindow = Duration(minutes: 5);

  late final _app = Core.get<AppStore>();
  late final _appStart = Core.get<AppStartStore>();
  late final _modal = Core.get<CurrentModalValue>();

  final DateTime Function() _now;
  final _confirmed = StreamController<void>.broadcast();

  DateTime? _activationRequestedAt;

  PowerActor({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Fires once each time protection the user switched on comes up.
  Stream<void> get onProtectionConfirmed => _confirmed.stream;

  @override
  Future<void> onCreate(Marker m) async {
    _app.addOn(appStatusChanged, _onAppStatus);
  }

  /// Switches protection on, or off when it is on (freemium, long press).
  Future<void> toggle(Marker m) async {
    return await log(m).trace("powerToggle", (m) async {
      if (_app.status.isActive()) {
        _activationRequestedAt = null;
      } else {
        _activationRequestedAt = _now();
      }

      try {
        await _appStart.toggleApp(m);
      } on OnboardingException catch (_) {
        // Activation continues after onboarding, so the request stays pending.
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }

  /// Pauses for [duration], or turns protection off when it is null.
  Future<void> pause(Marker m, Duration? duration) async {
    return await log(m).trace("powerPause", (m) async {
      _activationRequestedAt = null;
      await _appStart.toggleApp(m, duration: duration);
    });
  }

  Future<void> _onAppStatus(Marker m) async {
    if (!_app.status.isActive()) return;

    final requestedAt = _activationRequestedAt;
    if (requestedAt == null) return;
    _activationRequestedAt = null;

    if (_now().difference(requestedAt) > confirmWindow) {
      log(m).i("protection up too long after the switch-on request, not confirming");
      return;
    }

    log(m).i("protection confirmed");
    _confirmed.add(null);
  }
}

class HomeModule with Module {
  @override
  onCreateModule() async {
    await register(PowerActor());
  }
}
