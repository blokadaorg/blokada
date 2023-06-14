import 'package:common/stage/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../device/device.dart';
import '../stage/stage.dart';
import '../util/config.dart';
import '../util/cooldown.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'deck.g.dart';

typedef DeckId = String;
typedef ListId = String;

extension DeckExt on Deck {
  Deck add(ListId listId, String tag, bool enabled) {
    final newItems = Map.of(items);
    newItems[listId] = DeckItem(id: listId, tag: tag, enabled: enabled);
    return Deck(
        deckId: deckId, items: newItems, enabled: this.enabled || enabled);
  }

  Deck changeEnabled(ListId id, bool enabled) {
    final newItems = Map.of(items);
    final previous = items[id]!;
    newItems[id] = DeckItem(id: id, tag: previous.tag, enabled: enabled);
    final deckEnabled = newItems.values.any((it) => it?.enabled ?? false);
    return Deck(deckId: deckId, items: newItems, enabled: deckEnabled);
  }

  String string() {
    return "($deckId: $enabled, items: ${items.values.map((it) => "{${it?.id}, '${it?.tag}', ${it?.enabled}}")}";
  }
}

extension DeckItemExt on DeckItem {
  isEnabled() => enabled ?? false;
}

class DeckStore = DeckStoreBase with _$DeckStore;

abstract class DeckStoreBase with Store, Traceable, Dependable, Cooldown {
  late final _ops = dep<DeckOps>();
  late final _api = dep<DeckJson>();
  late final _device = dep<DeviceStore>();
  late final _stage = dep<StageStore>();

  DeckStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _device.addOn(deviceChanged, onDeviceChanged);

    reactionOnStore((_) => decksChanges, (_) async {
      await _ops.doDecksChanged(decks.values.toList());
    });
  }

  @override
  attach(Act act) {
    depend<DeckOps>(getOps(act));
    depend<DeckJson>(DeckJson());
    depend<DeckStore>(this as DeckStore);
  }

  @observable
  ObservableMap<DeckId, Deck> decks = ObservableMap();

  // The above structure is complex and won't always trigger MobX reactions
  @observable
  int decksChanges = 0;

  @observable
  List<ListId> enabledByUser = [];

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final lists = await _api.getLists(trace);
      final Map<DeckId, Deck> decks = {};
      for (var list in lists) {
        final pathParts = list.path.split("/");
        if (pathParts.length < 4) {
          trace.addEvent("skipping list path: ${list.path}");
          continue;
        }

        final deckId = pathParts[2];
        final listTag = pathParts[3];

        final deck = decks[deckId];
        final enabled = enabledByUser.contains(list.id);
        if (deck != null) {
          decks[deckId] = deck.add(list.id, listTag, enabled);
        } else {
          decks[deckId] = Deck(
              deckId: deckId,
              items: {
                list.id: DeckItem(id: list.id, tag: listTag, enabled: enabled)
              },
              enabled: enabled);
        }
      }
      trace.addAttribute("decksLength", decks.length);
      trace.addAttribute(
          "decks", decks.values.map((it) => it.string()).toList());
      this.decks = ObservableMap.of(decks);
      decksChanges++;
    });
  }

  @action
  Future<void> setUserLists(
      Trace parentTrace, List<ListId> enabledByUser) async {
    return await traceWith(parentTrace, "setUserLists", (trace) async {
      this.enabledByUser = enabledByUser;
      for (var deck in decks.values) {
        for (var item in deck.items.values) {
          if (item == null) continue;
          if (enabledByUser.contains(item.id) && !item.enabled) {
            decks[deck.deckId] = deck.changeEnabled(item.id, true);
            decksChanges++;
          } else if (!enabledByUser.contains(item.id) && item.enabled) {
            decks[deck.deckId] = deck.changeEnabled(item.id, false);
            decksChanges++;
          }
        }
      }
    });
  }

  @action
  Future<void> setEnableList(Trace parentTrace, ListId id, bool enabled) async {
    return await traceWith(parentTrace, "setEnableList", (trace) async {
      final list =
          List<String>.from(enabledByUser); // Copy to perform this atomically
      if (enabled) {
        list.add(id);
      } else {
        list.remove(id);
      }
      await _device.setLists(trace, list);
      enabledByUser = list;
      for (var deck in decks.values) {
        if (deck.items.containsKey(id)) {
          decks[deck.deckId] = deck.changeEnabled(id, enabled);
          decksChanges++;
          break;
        }
      }
      trace.addAttribute("listId", id);
      trace.addAttribute("enabled", enabled);
    }, fallback: (trace) async {
      await _stage.showModal(trace, StageModal.fault);
    }, important: true);
  }

  @action
  Future<void> toggleListByTag(Trace parentTrace, DeckId id, String tag) async {
    return await traceWith(parentTrace, "setToggleListByTag", (trace) async {
      final deck = decks[id];
      final list = deck?.items.values.firstWhere((it) => it?.tag == tag);
      if (list != null) {
        await setEnableList(parentTrace, list.id, !list.enabled);
      } else {
        throw Exception("List not found: ($id, $tag)");
      }
    }, fallback: (trace) async {
      await _stage.showModal(trace, StageModal.fault);
    });
  }

  @action
  Future<void> setEnableDeck(Trace parentTrace, DeckId id, bool enabled) async {
    return await traceWith(parentTrace, "setEnableDeck", (trace) async {
      final deck = decks[id];
      if (deck != null) {
        if (enabled) {
          // If no list in active in this deck, activate first
          if (!deck.items.values.any((it) => it?.enabled ?? false)) {
            final first = deck.items.values.first!;
            await setEnableList(trace, first.id, true);
          }
        } else {
          // Deactivate any active lists for this deck
          final active = deck.items.values.where((it) => it?.enabled ?? false);
          for (var item in active) {
            if (item == null) continue;
            await setEnableList(trace, item.id, false);
          }
        }
      } else {
        throw Exception("Deck not found: $id");
      }
    }, fallback: (trace) async {
      await _stage.showModal(trace, StageModal.fault);
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isForeground()) return;
    if (decks.isEmpty) {
      // Make sure we fetch it at least once even if user does not navigate to
      // the advanced tab. We need pack names to display activity screen too.
      return await traceWith(parentTrace, "fetchWhenEmpty", (trace) async {
        await fetch(trace);
      });
    }

    if (!route.isBecameTab(StageTab.advanced)) return;
    if (!isCooledDown(cfg.deckRefreshCooldown)) return;

    return await traceWith(parentTrace, "fetchDecks", (trace) async {
      await fetch(trace);
    });
  }

  @action
  Future<void> onDeviceChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onDeviceChanged", (trace) async {
      await setUserLists(trace, _device.lists!);
    });
  }
}
