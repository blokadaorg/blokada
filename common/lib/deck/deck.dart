import 'package:collection/collection.dart';
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
import 'mapper.dart';

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
  isEnabled() => enabled;
  getDeckId() => tag.split("/")[0];
}

const _defaultListSelection = "05ea377c9a64cba97bf8a6f38cb3a7fa"; // OISD small

class DeckStore = DeckStoreBase with _$DeckStore;

abstract class DeckStoreBase with Store, Traceable, Dependable, Cooldown {
  late final _ops = dep<DeckOps>();
  late final _api = dep<DeckJson>();
  late final _device = dep<DeviceStore>();
  late final _stage = dep<StageStore>();
  late final _mapper = dep<DeckMapper>();

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
    depend<DeckMapper>(act.isFamily() ? FamilyDeckMapper() : CloudDeckMapper());
    depend<DeckStore>(this as DeckStore);
  }

  @observable
  ObservableMap<DeckId, Deck> decks = ObservableMap();

  // The above structure is complex and won't always trigger MobX reactions
  @observable
  int decksChanges = 0;

  @observable
  List<ListId> enabledByUser = [];

  final Map<String, ListId> _listTagToId = {};

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final lists = await _api.getLists(trace);
      final deckItems = _convertToDeckItems(trace, lists);
      var decks = _mapper.bundleDeckItems(trace, deckItems);
      decks =
          _mapper.syncEnabledStates(trace, decks, enabledByUser, _listTagToId);
      trace.addAttribute("decksLength", decks.length);
      trace.addAttribute(
          "decks", decks.values.map((it) => it.string()).toList());
      this.decks = ObservableMap.of(decks);
      decksChanges++;
    });
  }

  List<DeckItem> _convertToDeckItems(Trace trace, List<JsonListItem> lists) {
    final List<DeckItem> items = [];
    for (var list in lists) {
      final pathParts = list.path.split("/");
      if (pathParts.length < 4) {
        trace.addEvent("skipping list path: ${list.path}");
        continue;
      }

      final listTag = "${pathParts[2]}/${pathParts[3]}";

      items.add(DeckItem(id: list.id, tag: listTag, enabled: false));
      _listTagToId[listTag] = list.id;
    }
    return items;
  }

  @action
  Future<void> setUserLists(
      Trace parentTrace, List<ListId> enabledByUser) async {
    return await traceWith(parentTrace, "setUserLists", (trace) async {
      trace.addAttribute("enabledByUser", enabledByUser);
      this.enabledByUser = enabledByUser;
      decks = ObservableMap.of(
          _mapper.syncEnabledStates(trace, decks, enabledByUser, _listTagToId));
      decksChanges++;
    });
  }

  @action
  Future<void> setEnableList(Trace parentTrace, ListId id, bool enabled) async {
    return await traceWith(parentTrace, "setEnableList", (trace) async {
      try {
        for (var deck in decks.values) {
          if (deck.items.containsKey(id)) {
            decks[deck.deckId] = deck.changeEnabled(id, enabled);
            decksChanges++;
            break;
          }
        }

        var mapped = _mapper.expandListBundle(trace, id);
        var ids = [id];
        if (mapped != null) {
          ids = mapped.map((e) => _listTagToId[e]!).toList();
        }

        // Copy to perform this atomically
        final list = List<String>.from(enabledByUser);
        if (enabled) {
          list.addAll(ids);
        } else {
          list.removeWhere((e) => ids.contains(e));
        }
        await _device.setLists(trace, list);
        enabledByUser = list;

        trace.addAttribute("listId", id);
        trace.addAttribute("enabled", enabled);
      } catch (_) {
        await _stage.showModal(trace, StageModal.fault);
        rethrow;
      }
    }, important: true);
  }

  @action
  Future<void> toggleListByTag(Trace parentTrace, DeckId id, String tag) async {
    return await traceWith(parentTrace, "setToggleListByTag", (trace) async {
      try {
        final deck = decks[id];
        tag = "$id/$tag";
        final list =
            deck?.items.values.firstWhereOrNull((it) => it?.tag == tag);
        if (list != null) {
          await setEnableList(parentTrace, list.id, !list.enabled);
        } else {
          throw Exception("List not found: ($id, $tag)");
        }
      } catch (_) {
        await _stage.showModal(trace, StageModal.fault);
        rethrow;
      }
    });
  }

  @action
  Future<void> setEnableDeck(Trace parentTrace, DeckId id, bool enabled) async {
    return await traceWith(parentTrace, "setEnableDeck", (trace) async {
      try {
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
            final active =
                deck.items.values.where((it) => it?.enabled ?? false);
            for (var item in active) {
              if (item == null) continue;
              await setEnableList(trace, item.id, false);
            }
          }
        } else {
          throw Exception("Deck not found: $id");
        }
      } catch (_) {
        await _stage.showModal(trace, StageModal.fault);
        rethrow;
      }
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
      if (_device.lists!.isEmpty) {
        trace.addEvent("Empty selection, setting default");
        return await setEnableList(trace, _defaultListSelection, true);
      }
    });
  }
}
