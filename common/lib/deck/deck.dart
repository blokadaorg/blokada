import 'package:mobx/mobx.dart';

import '../device/device.dart';
import '../util/di.dart';
import '../util/trace.dart';
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

abstract class DeckStoreBase with Store, Traceable {
  late final _api = di<DeckJson>();
  late final _device = di<DeviceStore>();

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
    });
  }
}

class DeckBinder with DeckEvents, Traceable {
  late final _store = di<DeckStore>();
  late final _ops = di<DeckOps>();
  late final _device = di<DeviceStore>();

  DeckBinder() {
    DeckEvents.setup(this);
    _onDeviceLists();
    _onDecksChanged();
  }

  DeckBinder.forTesting() {
    _onDeviceLists();
    _onDecksChanged();
  }

  @override
  Future<void> onEnableDeck(String deckId, bool enable) async {
    await traceAs("onEnableDeck", (trace) async {
      await _store.setEnableDeck(trace, deckId, enable);
    });
  }

  @override
  Future<void> onEnableList(String listId, bool enable) async {
    await traceAs("onEnableList", (trace) async {
      await _store.setEnableList(trace, listId, enable);
    });
  }

  @override
  Future<void> onToggleListByTag(String deckId, String tag) async {
    await traceAs("onToggleListByTag", (trace) async {
      await _store.toggleListByTag(trace, deckId, tag);
    });
  }

  _onDeviceLists() {
    reaction((_) => _device.lists, (lists) async {
      if (lists != null) {
        await traceAs("onDeviceLists", (trace) async {
          await _store.setUserLists(trace, lists);
        });
      }
    });
  }

  _onDecksChanged() {
    reaction((_) => _store.decksChanges, (_) async {
      await traceAs("onDecksChanged", (trace) async {
        await _ops.doDecksChanged(_store.decks.values.toList());
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<DeckJson>(DeckJson());
  di.registerSingleton<DeckStore>(DeckStore());
  di.registerSingleton<DeckOps>(DeckOps());
  DeckBinder();
}
