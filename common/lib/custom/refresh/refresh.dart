import 'package:mobx/mobx.dart';

import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../custom.dart';

part 'refresh.g.dart';

const _refreshCooldown = Duration(seconds: 10);

class CustomRefreshStore = CustomRefreshStoreBase with _$CustomRefreshStore;

abstract class CustomRefreshStoreBase with Store, Traceable {
  late final _store = di<CustomStore>();

  @observable
  DateTime lastRefresh = DateTime(0);

  @action
  Future<void> maybeRefresh(Trace parentTrace) async {
    return await traceWith(parentTrace, "maybeRefresh", (trace) async {
      final now = DateTime.now();
      if (now.difference(lastRefresh).compareTo(_refreshCooldown) > 0) {
        await _store.fetch(trace);
        lastRefresh = now;
        trace.addEvent("refreshed");
      }
    });
  }
}

class CustomRefreshBinder with Traceable {
  late final _store = di<CustomRefreshStore>();
  late final _stage = di<StageStore>();

  CustomRefreshBinder() {
    _onJournalTab();
  }

  _onJournalTab() {
    reaction((_) => _stage.activeTab, (tab) async {
      if (tab == StageTab.activity) {
        await traceAs("onJournalTab", (trace) async {
          await _store.maybeRefresh(trace);
        });
      }
    });
  }
}

Future<void> init() async {
  di.registerSingleton<CustomRefreshStore>(CustomRefreshStore());
  CustomRefreshBinder();
}
