import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/account/domain/account.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/list/domain/list.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/device/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../../tools.dart';
import '../device/pause_origin.dart';
@GenerateNiceMocks([
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
])
import 'actor_test.mocks.dart';

const _small = "id-oisd-small";
const _big = "id-oisd-big";
const _nsfw = "id-oisd-nsfw";

/// Stands in for the v2 device endpoint: PUT stores the lists and the safe
/// search flag, GET returns them. [fail] makes every PUT reject like a failed
/// request, [failNext] only that many, [failGet] the GET, and [gate] holds
/// the next PUT until completed.
class _FakeDeviceApi extends DeviceApi {
  bool fail = false;
  int failNext = 0;
  bool failGet = false;
  Completer<void>? gate;
  List<String> stored = [_small];
  bool storedSafeSearch = false;
  final List<List<String>> puts = [];
  // The safe_search sent with each PUT in [puts], null when left out.
  final List<bool?> safeSearchPuts = [];

  @override
  Future<JsonDevice> getDevice(Marker m) async {
    if (failGet) throw Exception("network down");
    return JsonDevice(
        deviceTag: "example-tag",
        lists: stored.toList(),
        retention: "",
        paused: false,
        pausedForSeconds: 0,
        safeSearch: storedSafeSearch);
  }

  @override
  Future<void> putDevice(Marker m,
      {bool? paused,
      int? pausedForSeconds,
      List<String>? lists,
      String? retention,
      bool? safeSearch}) async {
    puts.add(lists!);
    safeSearchPuts.add(safeSearch);
    // Decided when the PUT starts, so a later PUT can finish first.
    final failThis = failNext > 0;
    if (failThis) failNext--;
    final held = gate;
    gate = null;
    await held?.future;
    if (failThis) throw Exception("network down");
    if (fail) throw Exception("network down");
    stored = lists.toList();
    if (safeSearch != null) storedSafeSearch = safeSearch;
  }
}

// Lists beyond OISD, for the v6 main list and extras.
const _unified = "id-stevenblack-unified";
const _adult = "id-stevenblack-adult";
const _adaway = "id-adaway-standard";
const _noSafeSearch = "id-safesearch-nosafesearch";

class _FakeListApi extends ListApi {
  /// Also lists Steven Black and AdAway, which the older tests rely on
  /// being missing from the catalog.
  final bool wide;

  _FakeListApi({this.wide = false});

  @override
  Future<List<JsonListItem>> get(Marker m) async => [
        _list(_small, "oisd", "small"),
        _list(_big, "oisd", "big"),
        _list(_nsfw, "oisd", "nsfw"),
        if (wide) ...[
          _list(_unified, "stevenblack", "unified"),
          _list(_adult, "stevenblack", "adult"),
          _list(_adaway, "adaway", "standard"),
          _list(_noSafeSearch, "safesearch", "nosafesearch"),
        ],
      ];

  JsonListItem _list(String id, String vendor, String variant) => JsonListItem(
        id: id,
        path: "mirror/v5/$vendor/$variant/hosts.txt",
        vendor: vendor,
        variant: variant,
        managed: true,
        allowlist: false,
      );
}

class _FakeEnvActor extends EnvActor {
  @override
  String get deviceName => "Example iPhone";
}

class _FakeAccountActor extends AccountActor {
  @override
  Future<void> onStart(Marker m) async {}
}

class _RecordingToast extends ToastActor {
  final List<String> shown = [];
  final List<String> errors = [];

  @override
  void show(String text) => shown.add(text);

  @override
  void showError(String text) => errors.add(text);
}

class _Subject {
  final PlatformFilterActor actor;
  final _FakeDeviceApi api;
  final _RecordingToast toast;

  _Subject(this.actor, this.api, this.toast);

  CurrentConfig get config => Core.get<CurrentConfig>();

  Future<List<String>> oisd() async {
    final selected = await Core.get<SelectedFilters>().now();
    return selected.firstWhere((it) => it.filterName == "oisd").options;
  }

  /// The main list as the v6 screen shows it.
  Future<BlocklistKey?> main(Marker m) async {
    final pick = await Core.get<BlocklistMainPick>().fetch(m);
    return v6MainBlocklist(await Core.get<SelectedFilters>().now(),
        pick: BlocklistKey.fromTag(pick));
  }

  /// The lists that are on besides the main one.
  Future<Set<BlocklistKey>> extras(Marker m) async {
    final main = await this.main(m);
    return selectedBlocklists(await Core.get<SelectedFilters>().now())
      ..remove(main);
  }
}

/// Wires the real filter, device and legacy filter actors over fake
/// endpoints, and waits until the device's lists show as selected.
Future<_Subject> _boot(Marker m,
    {List<String>? stored, bool safeSearch = false, bool wide = false}) async {
  Core.register<StageStore>(MockStageStore());
  Core.register<AccountStore>(MockAccountStore());
  Core.register<EnvActor>(_FakeEnvActor());
  registerMemoryPauseOrigin();
  Core.register<AccountActor>(_FakeAccountActor());
  final toast = _RecordingToast();
  Core.register<ToastActor>(toast);

  final api = _FakeDeviceApi();
  if (stored != null) api.stored = stored;
  api.storedSafeSearch = safeSearch;
  Core.register<DeviceApi>(api);
  final device = DeviceStore();
  Core.register<DeviceStore>(device);

  Core.register<ListApi>(_FakeListApi(wide: wide));
  Core.register<Persistence>(Persistence(isSecure: false));
  Core.register<BlocklistMainPick>(BlocklistMainPick());
  Core.register<KnownFilters>(KnownFilters(isFamily: false));
  Core.register<DefaultFilters>(DefaultFilters(false));
  Core.register<CurrentConfig>(CurrentConfig());
  Core.register<SelectedFilters>(SelectedFilters());
  Core.register<FilterActor>(FilterActor());

  final actor = PlatformFilterActor(debounce: const Duration(milliseconds: 300));
  Core.register<PlatformFilterActor>(actor);
  await actor.onStart(m);

  await device.fetch(m, force: true);
  await _settle();
  return _Subject(actor, api, toast);
}

/// Lets the debounced save and the refresh it triggers finish.
Future<void> _settle() async {
  await Future.delayed(const Duration(milliseconds: 600));
  await pumpEventQueue();
}

/// The time between two quick taps, shorter than the debounce. Back to back
/// toggles with no gap race the filter reload, which a person can't do.
Future<void> _tapGap() => Future.delayed(const Duration(milliseconds: 50));

void main() {
  group("toggleFilterOption", () {
    test("successfulSaveShowsNoToast", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        expect(await s.oisd(), ["small"]);

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.api.puts, [
          [_small, _big]
        ]);
        expect(await s.oisd(), ["small", "big"]);
        expect(s.toast.shown, isEmpty);
        expect(s.toast.errors, isEmpty);
      });
    });

    test("failedSaveRevertsToPreviousSelection", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        s.api.fail = true;

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(await s.oisd(), ["small"]);
      });
    });

    test("failedSaveShowsErrorNotConfirmation", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        s.api.fail = true;

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
      });
    });

    test("rapidTogglesSaveOnce", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _tapGap();
        await s.actor.toggleFilterOption("oisd", "nsfw", m);
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(s.api.puts.single.toSet(), {_small, _big, _nsfw});
        expect(s.toast.shown, isEmpty);
        expect(s.toast.errors, isEmpty);
      });
    });

    test("toggleUndoneBeforeSaveSendsNothing", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _tapGap();
        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.api.puts, isEmpty);
        expect(s.toast.shown, isEmpty);
        expect(s.toast.errors, isEmpty);
      });
    });

    test("failureBeforeSaveRestoresPreviousSelection", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        // An option the filter does not know makes building the config throw.
        await s.actor.toggleFilterOption("oisd", "unknown", m);
        await _settle();

        expect(await s.oisd(), ["small"]);
        expect(s.api.puts, isEmpty);
        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
      });
    });
    test("refreshFailureAfterSaveShowsNoError", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        s.api.failGet = true;

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.api.stored, [_small, _big]);
        expect(await s.oisd(), ["small", "big"]);
        expect(s.toast.shown, isEmpty);
        expect(s.toast.errors, isEmpty);
      });
    });

    test("toggleDuringFailedSaveIsKept", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        s.api.failNext = 1;
        final held = s.api.gate = Completer();

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle(); // The first save is now waiting on the server.
        await s.actor.toggleFilterOption("oisd", "nsfw", m);
        held.complete();
        await _settle();

        expect(s.api.puts, hasLength(2));
        expect(s.api.stored.toSet(), {_small, _big, _nsfw});
        expect(await s.oisd(), ["small", "big", "nsfw"]);
        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
      });
    });

    test("failedRollbackIsHandled", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        s.api.fail = true;

        await s.actor.toggleFilterOption("oisd", "big", m);
        s.config.save = (m, _) async => throw Exception("storage down");
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
      });
    });

    test("failedConfigChangeLeavesLaterSavesSilent", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        s.config.save = (m, _) async => throw Exception("storage down");
        await s.actor.toggleFilterOption("oisd", "big", m);
        s.config.save = null;
        await _settle();
        expect(s.toast.errors, ["toast save failed".i18n]);

        // A save nobody asked for, like the defaults.
        await s.config.change(m, UserFilterConfig({_small, _nsfw}, {}));
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(s.toast.shown, isEmpty);
      });
    });

    test("unchangedConfigLeavesLaterSavesSilent", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        // Not in the list catalog, so the config stays the same.
        await s.actor.toggleFilterOption("stevenblack", "unified", m);
        await _settle();
        expect(s.api.puts, isEmpty);

        // A save nobody asked for, like the defaults.
        await s.config.change(m, UserFilterConfig({_small, _nsfw}, {}));
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(s.toast.shown, isEmpty);
        expect(s.toast.errors, isEmpty);
      });
    });
  });

  group("v6 blocklists", () {
    const small = BlocklistKey("oisd", "small");
    const big = BlocklistKey("oisd", "big");
    const nsfw = BlocklistKey("oisd", "nsfw");
    const unified = BlocklistKey("stevenblack", "unified");
    const adult = BlocklistKey("stevenblack", "adult");
    const adaway = BlocklistKey("adaway", "standard");

    test("freshAccountGetsOisdSmallAsMain", () async {
      await withTrace((m) async {
        // The server has nothing yet, so the defaults go on at start.
        final s = await _boot(m, stored: [], wide: true);

        expect(await s.main(m), small);
        expect(await s.extras(m), isEmpty);
        expect(s.api.puts, [
          [_small]
        ]);
      });
    });

    test("loadingExistingSelectionSavesNothing", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_big, _adaway], wide: true);

        expect(await s.main(m), big);
        expect(await s.extras(m), {adaway});
        expect(s.api.puts, isEmpty);
        expect(s.toast.shown, isEmpty);
      });
    });

    test("twoGeneralListsFirstInMainOrderIsMain", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_unified, _big], wide: true);

        expect(await s.main(m), big);
        expect(await s.extras(m), {unified});
        expect(s.api.puts, isEmpty);
      });
    });

    test("noMainListIsLeftAsIs", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_adaway], wide: true);

        expect(await s.main(m), isNull);
        expect(await s.extras(m), {adaway});
        expect(s.api.puts, isEmpty);
      });
    });

    test("mainChangeSwapsListsInOneSave", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small, _nsfw], wide: true);

        await s.actor.selectMainBlocklist(unified, m);
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(s.api.puts.single.toSet(), {_unified, _nsfw});
        expect(await s.main(m), unified);
        expect(await s.extras(m), {nsfw});
        expect(s.toast.shown, isEmpty);
      });
    });

    test("mainPickTurnsOffEveryOtherGeneralList", () async {
      await withTrace((m) async {
        // Stacked general lists from before the main pick existed.
        final s = await _boot(m, stored: [_small, _big, _nsfw], wide: true);

        await s.actor.selectMainBlocklist(unified, m);
        await _settle();

        expect(s.api.puts.single.toSet(), {_unified, _nsfw});
        expect(await s.main(m), unified);
        expect(await s.extras(m), {nsfw});
        expect(s.toast.shown, isEmpty);
      });
    });

    test("pickingTheStackedMainDropsTheOthers", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small, _big], wide: true);

        await s.actor.selectMainBlocklist(small, m);
        await _settle();

        expect(s.api.puts.single, [_small]);
        expect(await s.main(m), small);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("failedMainChangeShowsErrorAndPutsBackServerSelection", () async {
      await withTrace((m) async {
        // OISD Small sorts first, so only the stored pick keeps Big as main.
        final s = await _boot(m, stored: [_small, _big], wide: true);
        await Core.get<BlocklistMainPick>().change(m, big.tag);
        expect(await s.main(m), big);

        s.api.fail = true;
        await s.actor.selectMainBlocklist(unified, m);
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
        expect(s.api.stored.toSet(), {_small, _big});
        expect(await s.main(m), big);
        expect(await s.extras(m), {small});
      });
    });

    test("failedExtraToggleShowsErrorAndRollsBack", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);
        s.api.fail = true;

        await s.actor.toggleExtraBlocklist(adult, true, m);
        expect(await s.extras(m), {adult}); // Shown before the save.
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(s.toast.shown, isEmpty);
        expect(await s.main(m), small);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("olderFailedSaveKeepsNewerPick", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small, _big], wide: true);
        await s.actor.selectMainBlocklist(unified, m);
        await _settle();

        // The main change waits on the server, then fails after the extra
        // toggle that followed it was saved.
        s.api.failNext = 1;
        final held = s.api.gate = Completer();
        await s.actor.selectMainBlocklist(small, m);
        await _settle();
        await s.actor.toggleExtraBlocklist(adult, true, m);
        await _settle();
        held.complete();
        await _settle();

        expect(s.api.stored.toSet(), {_small, _adult});
        expect(await s.main(m), small);
        expect(await s.extras(m), {adult});
      });
    });

    test("generalListIsNotAnExtra", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);

        await s.actor.toggleExtraBlocklist(big, true, m);
        await _settle();

        expect(s.api.puts, isEmpty);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("pickingAnExtraAsMainDropsTheOldMain", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small, _big], wide: true);

        await s.actor.selectMainBlocklist(big, m);
        await _settle();

        expect(s.api.puts.single, [_big]);
        expect(await s.main(m), big);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("pickingTheCurrentMainSendsNothing", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);

        await s.actor.selectMainBlocklist(small, m);
        await _settle();

        expect(s.api.puts, isEmpty);
      });
    });

    test("pickingMainWithNoneOnAddsIt", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_adaway], wide: true);

        await s.actor.selectMainBlocklist(small, m);
        await _settle();

        expect(s.api.puts.single.toSet(), {_small, _adaway});
        expect(await s.main(m), small);
      });
    });

    test("extraToggleKeepsMain", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);

        await s.actor.toggleExtraBlocklist(adult, true, m);
        await _settle();
        expect(s.api.puts.last.toSet(), {_small, _adult});
        expect(await s.extras(m), {adult});

        await s.actor.toggleExtraBlocklist(adult, false, m);
        await _settle();
        expect(s.api.puts.last, [_small]);
        expect(await s.main(m), small);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("lastListCannotBeTurnedOff", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_adaway], wide: true);

        await s.actor.toggleExtraBlocklist(adaway, false, m);
        await _settle();

        expect(s.api.puts, isEmpty);
        expect(await s.extras(m), {adaway});
      });
    });

    test("noTapSequenceEmptiesTheLists", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);
        final configs = <UserFilterConfig?>[];
        s.config.onChange.listen((it) => configs.add(it.now));

        // Every main pick and every extra both ways, as the screen offers them.
        for (final key in [big, unified, small]) {
          await s.actor.selectMainBlocklist(key, m);
          await _tapGap();
          for (final extra in [nsfw, adult, adaway]) {
            await s.actor.toggleExtraBlocklist(extra, true, m);
            await _tapGap();
            await s.actor.toggleExtraBlocklist(extra, false, m);
            await _tapGap();
          }
        }
        await _settle();

        expect(configs.where((it) => it == null || it.lists.isEmpty), isEmpty);
        expect(s.api.puts.where((it) => it.isEmpty), isEmpty);
        expect(await s.main(m), small);
        expect(await s.extras(m), isEmpty);
      });
    });
  });

  group("v6 safe search", () {
    const small = BlocklistKey("oisd", "small");
    const adaway = BlocklistKey("adaway", "standard");
    const safeSearch = BlocklistKey(filterSafeSearch, filterOptionSafeSearch);

    test("offByDefault", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [], wide: true);

        expect(await s.extras(m), isEmpty);
        expect(s.api.puts, [
          [_small]
        ]);
        expect(s.api.storedSafeSearch, isFalse);
      });
    });

    test("turningOnSendsListAndFlagInOneSave", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);

        await s.actor.toggleExtraBlocklist(safeSearch, true, m);
        await _settle();

        expect(s.api.puts.single.toSet(), {_small, _noSafeSearch});
        expect(s.api.safeSearchPuts, [true]);
        expect(s.api.storedSafeSearch, isTrue);
        expect(await s.main(m), small);
        expect(await s.extras(m), {safeSearch});
        expect(s.toast.errors, isEmpty);
      });
    });

    test("turningOffClearsListAndFlagInOneSave", () async {
      await withTrace((m) async {
        final s = await _boot(m,
            stored: [_small, _noSafeSearch], safeSearch: true, wide: true);

        await s.actor.toggleExtraBlocklist(safeSearch, false, m);
        await _settle();

        expect(s.api.puts, [
          [_small]
        ]);
        expect(s.api.safeSearchPuts, [false]);
        expect(s.api.storedSafeSearch, isFalse);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("loadingItFromTheDeviceSavesNothing", () async {
      await withTrace((m) async {
        final s = await _boot(m,
            stored: [_small, _noSafeSearch], safeSearch: true, wide: true);

        expect(await s.main(m), small);
        expect(await s.extras(m), {safeSearch});
        expect(s.config.present?.configs,
            {FilterConfigKey.safeSearch: true});
        expect(s.api.puts, isEmpty);
      });
    });

    test("listChangeKeepsIt", () async {
      await withTrace((m) async {
        final s = await _boot(m,
            stored: [_small, _noSafeSearch], safeSearch: true, wide: true);

        await s.actor.toggleExtraBlocklist(adaway, true, m);
        await _settle();

        expect(s.api.puts.single.toSet(), {_small, _noSafeSearch, _adaway});
        expect(s.api.safeSearchPuts, [true]);
        expect(await s.extras(m), {safeSearch, adaway});
      });
    });

    test("toggleUndoneBeforeSaveSendsNothing", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);

        await s.actor.toggleExtraBlocklist(safeSearch, true, m);
        await _tapGap();
        await s.actor.toggleExtraBlocklist(safeSearch, false, m);
        await _settle();

        expect(s.api.puts, isEmpty);
        expect(await s.extras(m), isEmpty);
      });
    });

    test("failedSaveShowsErrorAndRollsBack", () async {
      await withTrace((m) async {
        final s = await _boot(m, wide: true);
        s.api.fail = true;

        await s.actor.toggleExtraBlocklist(safeSearch, true, m);
        expect(await s.extras(m), {safeSearch}); // Shown before the save.
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(await s.extras(m), isEmpty);
        expect(s.config.present?.configs, isEmpty);
      });
    });

    test("failedTurnOffShowsErrorAndPutsItBack", () async {
      await withTrace((m) async {
        final s = await _boot(m,
            stored: [_small, _noSafeSearch], safeSearch: true, wide: true);
        s.api.fail = true;

        await s.actor.toggleExtraBlocklist(safeSearch, false, m);
        await _settle();

        expect(s.toast.errors, ["toast save failed".i18n]);
        expect(await s.extras(m), {safeSearch});
        expect(s.config.present?.configs,
            {FilterConfigKey.safeSearch: true});
      });
    });

    // The shared filter logic treats either half as the filter being on and
    // completes the other, the same as in Family.
    test("flagWithoutListIsCompleted", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small], safeSearch: true, wide: true);

        expect(await s.extras(m), {safeSearch});
        expect(s.api.puts.single.toSet(), {_small, _noSafeSearch});
        expect(s.api.safeSearchPuts, [true]);
      });
    });

    test("listWithoutFlagIsCompleted", () async {
      await withTrace((m) async {
        final s = await _boot(m, stored: [_small, _noSafeSearch], wide: true);

        expect(await s.extras(m), {safeSearch});
        expect(s.api.puts.single.toSet(), {_small, _noSafeSearch});
        expect(s.api.safeSearchPuts, [true]);
      });
    });

    test("aloneStillGetsTheDefaultLists", () async {
      await withTrace((m) async {
        // None of the device's lists is in the catalog any more.
        final s = await _boot(m,
            stored: ["id-gone"], safeSearch: true, wide: true);

        expect(await s.main(m), small);
        expect(await s.extras(m), {safeSearch});
        expect(s.api.stored.toSet(), {_small, _noSafeSearch});
        expect(s.api.storedSafeSearch, isTrue);
      });
    });

    test("doesNotCountAsTheLastList", () async {
      await withTrace((m) async {
        final s = await _boot(m,
            stored: [_adaway, _noSafeSearch], safeSearch: true, wide: true);

        await s.actor.toggleExtraBlocklist(adaway, false, m);
        await _settle();

        expect(s.api.puts, isEmpty);
        expect(await s.extras(m), {adaway, safeSearch});
      });
    });
  });
}
