import 'package:collection/collection.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:dartx/dartx.dart';
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
const _defaultListSelectionFamily = "meta_ads/standard";

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
  bool _listsSet = false;

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
      await _ops.doTagMappingChanged(_mapper.mapDeckItemTags(trace, deckItems));
      if (enabledByUser.isNotEmpty) await setUserLists(trace, enabledByUser);
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

      if (decks.isEmpty) {
        // We don't have decks yet, so we can't sync the enabled states
        trace.addEvent("decks is empty, skipping");
        return;
      }

      decks = ObservableMap.of(
          _mapper.syncEnabledStates(trace, decks, enabledByUser, _listTagToId));
      decksChanges++;

      // Make sure there is no selected lists that we don't know

      // First, make a list of all ListIds that are selected that we know
      final knownLists = decks.filter((d) => d.value.enabled).mapValues((it) =>
          it.value.items.values
              .mapNotNull((it) => (it?.enabled ?? false) ? it?.id : null));
      var knownIds = knownLists.values
          .expand((it) => it)
          .map((it) => _getMappedIds(trace, it))
          .expand((it) => it)
          .distinct()
          .toList();

      if (knownIds.isEmpty && !_listsSet) {
        // Use default selection for this flavor, but only on first set attempt
        final def = act.isFamily()
            ? _defaultListSelectionFamily
            : _defaultListSelection;
        knownIds = _getMappedIds(trace, def);
      }

      // Then, compare to enabledByUser
      final unknownLists = enabledByUser.where((it) => !knownIds.contains(it));
      if (unknownLists.isNotEmpty) {
        trace.addEvent("enabledByUser has unknown list, re-setting");
        trace.addEvent("enabledByUser: $enabledByUser");
        trace.addEvent("known: $knownIds");

        _listsSet = true;
        await _device.setLists(trace, knownIds);
      } else if (!_listsSet && enabledByUser.isEmpty) {
        trace.addEvent("Empty selection, setting default");
        _listsSet = true;
        await _device.setLists(trace, knownIds);
      } else {
        _listsSet = true;
      }
    });
  }

  List<String> _getMappedIds(Trace trace, ListId id) {
    final mapped = _mapper.expandListBundle(trace, id);
    if (mapped == null) return [id];
    return mapped.map((e) => _listTagToId[e]!).toList();
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

        final ids = _getMappedIds(trace, id);

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
        final lists = _device.lists;
        if (lists != null) await setUserLists(trace, lists);
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
      final lists = _device.lists;
      if (lists != null && decks.isNotEmpty) {
        await setUserLists(trace, lists);
      }
    });
  }
}
