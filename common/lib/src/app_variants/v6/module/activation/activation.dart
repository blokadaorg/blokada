import 'dart:async';

import 'package:common/src/app_variants/v6/widget/activation/activation_intro_sheet.dart';
import 'package:common/src/app_variants/v6/widget/activation/first_blocks_sheet.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/platform/stats/stats.dart';

part 'goals.dart';

/// The guided post-purchase activation of Blokada 6 (#457). Instead of the
/// DNS wizard followed by an idle home, a new paid user picks what to block,
/// answers the activity logging question, sets up DNS, and then watches the
/// first blocks come in. Only the [ActivationFlow.guided] cohort sees it; the
/// control cohort keeps the plain DNS wizard (see V6OnboardActor).
class V6ActivationModule with Module {
  @override
  onCreateModule() async {
    await register(V6ActivationActor());
  }
}

/// Where the guided flow is. It lives in memory only: the flow starts from a
/// purchase, and after an app restart the regular startup DNS checks take
/// over, so a half-done flow simply ends.
enum ActivationStep { none, intro, setup, firstBlocks }

/// What the first blocks sheet shows. With activity logging on the requests
/// themselves exist, so the user sees them; with it off only the counter is
/// real, because the DNS servers keep counts but no requests.
enum FirstBlocksMode { feedAndCounter, counterOnly }

FirstBlocksMode firstBlocksModeFor(DeviceRetention? retention) => (retention?.isEnabled() ?? false)
    ? FirstBlocksMode.feedAndCounter
    : FirstBlocksMode.counterOnly;

/// One refresh of the first blocks sheet.
class FirstBlocksSnapshot {
  final int blocked;
  final List<UiJournalEntry> entries;

  const FirstBlocksSnapshot(this.blocked, this.entries);
}

class V6ActivationActor with Actor, Logging {
  /// How long after the purchase a finished DNS setup still opens the first
  /// blocks sheet. iOS sends the user to Settings, so setup completes on a
  /// later foreground; long after that the moment has passed.
  static const firstBlocksWindow = Duration(minutes: 30);

  late final _account = Core.get<AccountStore>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();
  late final _perm = Core.get<PlatformPermActor>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
  late final _stage = Core.get<StageStore>();
  late final _device = Core.get<DeviceStore>();
  late final _filters = Core.get<PlatformFilterActor>();
  late final _selectedFilters = Core.get<SelectedFilters>();
  late final _statsController = Core.get<StatsController>();
  late final _stats = Core.get<StatsStore>();
  late final _journal = Core.get<JournalActor>();
  late final _notification = Core.get<NotificationActor>();

  /// Injectable for tests.
  DateTime Function() now = DateTime.now;

  ActivationStep _step = ActivationStep.none;
  ActivationStep get step => _step;

  DateTime? _startedAt;
  bool _loggingAnswered = false;

  @override
  onCreate(Marker m) async {
    _modal.onChange.listen((it) {
      if (it.now == Modal.activationIntro) {
        _modalWidget.change(it.m, (context) => const ActivationIntroSheet());
      } else if (it.now == Modal.activationFirstBlocks) {
        _modalWidget.change(it.m, (context) => const FirstBlocksSheet());
      }
      unawaited(_onModalChanged(it.old, it.now, it.m));
    });
  }

  @override
  onStart(Marker m) async {
    _dnsEnabledFor.onChange.listen((it) => unawaited(_maybeShowFirstBlocks(it.m)));
    _stage.addOnValue(routeChanged, _onRouteChanged);
  }

  /// Whether a purchase should run the guided flow rather than the plain DNS
  /// wizard. Restores never do: the user is not new.
  bool runsFor(bool restore) {
    if (restore) return false;
    return _account.account?.jsonAccount.getActivationFlow() == ActivationFlow.guided;
  }

  /// Starts the flow with the goals and logging sheet. It queues behind the
  /// paywall, which may still be closing when the purchase completes.
  Future<void> begin(Marker m) async {
    return await log(m).trace("activation:begin", (m) async {
      _step = ActivationStep.intro;
      _startedAt = now();
      _loggingAnswered = false;
      await _modal.change(m, Modal.activationIntro);
    });
  }

  /// The goals as they are on the device now, so a returning user sees the
  /// lists they already have.
  Set<ActivationGoal> currentGoals() {
    final on = selectedBlocklists(_selectedFilters.present ?? []);
    return {
      for (final goal in ActivationGoal.values)
        if (on.contains(goal.blocklist)) goal,
    };
  }

  /// Saves the picked goals the way the Advanced screen does: each goal is
  /// an extra blocklist, turned on or off only when it differs. The main
  /// list stays, so no pick can leave the device without blocking.
  Future<void> applyGoals(Set<ActivationGoal> picked, Marker m) async {
    return await log(m).trace("activation:applyGoals", (m) async {
      log(m).pair("goals", picked.map((it) => it.name).join(","));
      final on = selectedBlocklists(await _selectedFilters.now());
      for (final change in goalChanges(picked, on).entries) {
        await _filters.toggleExtraBlocklist(change.key, change.value, m);
      }
    });
  }

  /// Whether the logging question still needs asking. Users who already
  /// have logging on skip it.
  bool get asksAboutLogging => !(_device.retention?.isEnabled() ?? false);

  /// The user answered the logging question. Either answer replaces the
  /// activity logging reminder (#259); only turning logging on can fail, and
  /// then the question stays unanswered so the reminder still comes.
  Future<void> answerLogging(bool enable, Marker m) async {
    return await log(m).trace("activation:answerLogging", (m) async {
      log(m).pair("enable", enable);
      if (enable) await _statsController.enableLogging(m);
      _loggingAnswered = true;
      await _notification.dismiss(m, id: NotificationId.activityLoggingReminder);
    });
  }

  FirstBlocksMode get firstBlocksMode => firstBlocksModeFor(_device.retention);

  /// One refresh of the first blocks sheet: blocked requests in the last
  /// day, which for a new device is everything blocked so far, and with
  /// logging on the latest blocked requests.
  Future<FirstBlocksSnapshot> pollFirstBlocks(Marker m) async {
    final counters = await _stats.countersForRange("24h", m, force: true);
    if (firstBlocksMode == FirstBlocksMode.counterOnly) {
      return FirstBlocksSnapshot(counters.blocked, const []);
    }
    final entries = await _journal.fetchPreview(m, action: UiJournalAction.block, limit: 6);
    return FirstBlocksSnapshot(counters.blocked, entries);
  }

  Future<void> _onModalChanged(Modal? old, Modal? now, Marker m) async {
    if (_step == ActivationStep.intro &&
        old == Modal.activationIntro &&
        now != Modal.activationIntro) {
      await _onIntroClosed(m);
    } else if (_step == ActivationStep.firstBlocks &&
        old == Modal.activationFirstBlocks &&
        now != Modal.activationFirstBlocks) {
      _step = ActivationStep.none;
    }
    await _maybeShowFirstBlocks(m);
  }

  /// Hands over to the DNS sheet, or straight to the first blocks when DNS
  /// already works (a returning user whose profile is still installed).
  Future<void> _onIntroClosed(Marker m) async {
    await log(m).trace("activation:introClosed", (m) async {
      _step = ActivationStep.setup;
      if (!_loggingAnswered) {
        // Closed without an answer: keep the regular reminder.
        await _notification.scheduleActivityLoggingReminder(m);
      }
      if (!_perm.isPrivateDnsEnabled && _modal.present == null) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }

  Future<void> _onRouteChanged(StageRouteState route, Marker m) async {
    if (route.isBecameForeground()) await _maybeShowFirstBlocks(m);
  }

  /// Opens the first blocks sheet once DNS works, nothing else is on screen
  /// and the app is in front. Called on every change that could make that
  /// true, since on iOS setup finishes in Settings.
  Future<void> _maybeShowFirstBlocks(Marker m) async {
    if (_step != ActivationStep.setup) return;
    final started = _startedAt;
    if (started == null || now().difference(started) > firstBlocksWindow) {
      _step = ActivationStep.none;
      return;
    }
    if (!_perm.isPrivateDnsEnabled) return;
    if (_modal.present != null) return;
    if (!_stage.route.isForeground()) return;
    _step = ActivationStep.firstBlocks;
    await _modal.change(m, Modal.activationFirstBlocks);
  }
}
