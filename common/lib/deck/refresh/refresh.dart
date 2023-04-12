import 'package:mobx/mobx.dart';

import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../deck.dart';

part 'refresh.g.dart';

const _refreshCooldown = Duration(minutes: 10);

class DeckRefreshStore = DeckRefreshStoreBase with _$DeckRefreshStore;

abstract class DeckRefreshStoreBase with Store, Traceable {
  late final _store = di<DeckStore>();

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

class DeckRefreshBinder with Traceable {
  late final _store = di<DeckRefreshStore>();
  late final _stage = di<StageStore>();

  DeckRefreshBinder() {
    _onAdvancedTab();
  }

  _onAdvancedTab() {
    reaction((_) => _stage.activeTab, (tab) async {
      if (tab == StageTab.advanced) {
        await traceAs("onAdvancedTab", (trace) async {
          await _store.maybeRefresh(trace);
        });
      }
    });
  }
}

Future<void> init() async {
  di.registerSingleton<DeckRefreshStore>(DeckRefreshStore());
  DeckRefreshBinder();
}
