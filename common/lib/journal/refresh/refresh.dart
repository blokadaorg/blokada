import 'package:mobx/mobx.dart';

import '../../device/device.dart';
import '../../stage/stage.dart';
import '../../timer/timer.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../journal.dart';

part 'refresh.g.dart';

const _refreshIntervalOnTab = Duration(seconds: 10);

class JournalRefreshStore = JournalRefreshStoreBase with _$JournalRefreshStore;

abstract class JournalRefreshStoreBase with Store, Traceable {
  late final _store = di<JournalStore>();

  @observable
  bool refreshEnabled = false;

  @observable
  DateTime lastRefresh = DateTime(0);

  @action
  Future<void> maybeRefresh(Trace parentTrace) async {
    return await traceWith(parentTrace, "maybeRefresh", (trace) async {
      final now = DateTime.now();
      if (refreshEnabled &&
          now.difference(lastRefresh).compareTo(_refreshIntervalOnTab) > 0) {
        await _store.fetch(trace);
        lastRefresh = now;
        trace.addEvent("refreshed");
      }
    });
  }

  @action
  Future<void> enableRefresh(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "enableRefresh", (trace) async {
      refreshEnabled = enabled;
      if (refreshEnabled) {
        await maybeRefresh(trace);
      }
      trace.addAttribute("enabled", enabled);
    });
  }
}

const _timerKey = "journalRefresh";

class JournalRefreshBinder with Traceable {
  late final _store = di<JournalRefreshStore>();
  late final _stage = di<StageStore>();
  late final _cloud = di<DeviceStore>();
  late final _timer = di<TimerService>();

  JournalRefreshBinder() {
    _onJournalTab();
    _onBackground();
    _onTimerFired();
    _onRetentionChanged();
  }

  _onJournalTab() {
    reaction((_) => _stage.activeTab, (tab) async {
      if (tab == StageTab.activity) {
        await traceAs("onJournalTab", (trace) async {
          await _store.maybeRefresh(trace);
          _startTimer(trace);
        });
      } else {
        await traceAs("onJournalTab", (trace) async {
          _stopTimer(trace);
        });
      }
    });
  }

  _onBackground() {
    reaction((_) => _stage.isForeground, (isForeground) async {
      if (!isForeground) {
        await traceAs("onBackground", (trace) async {
          _stopTimer(trace);
        });
      }
    });
  }

  _onTimerFired() {
    _timer.addHandler(_timerKey, () async {
      await traceAs("onTimerFired", (trace) async {
        await _store.maybeRefresh(trace);
      }, deferred: (trace) async {
        _timer.set(_timerKey, DateTime.now().add(_refreshIntervalOnTab));
      });
    });
  }

  _onRetentionChanged() {
    reaction((_) => _cloud.retention, (retention) async {
      await traceAs("onRetentionChanged", (trace) async {
        _store.enableRefresh(trace, retention?.isEnabled() ?? false);
      });
    });
  }

  _startTimer(Trace trace) {
    _timer.set(_timerKey, DateTime.now().add(_refreshIntervalOnTab));
    trace.addEvent("started journal refresh");
  }

  _stopTimer(Trace trace) {
    _timer.unset(_timerKey);
    trace.addEvent("stopped journal refresh");
  }
}

Future<void> init() async {
  di.registerSingleton<JournalRefreshStore>(JournalRefreshStore());
  JournalRefreshBinder();
}
