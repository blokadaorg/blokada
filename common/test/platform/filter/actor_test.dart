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
@GenerateNiceMocks([
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
])
import 'actor_test.mocks.dart';

const _small = "id-oisd-small";
const _big = "id-oisd-big";
const _nsfw = "id-oisd-nsfw";

/// Stands in for the v2 device endpoint: PUT stores the lists, GET returns
/// them, and [fail] makes PUT reject like a failed request.
class _FakeDeviceApi extends DeviceApi {
  bool fail = false;
  List<String> stored = [_small];
  final List<List<String>> puts = [];

  @override
  Future<JsonDevice> getDevice(Marker m) async => JsonDevice(
        deviceTag: "example-tag",
        lists: stored.toList(),
        retention: "",
        paused: false,
        pausedForSeconds: 0,
        safeSearch: false,
      );

  @override
  Future<void> putDevice(Marker m,
      {bool? paused,
      int? pausedForSeconds,
      List<String>? lists,
      String? retention,
      bool? safeSearch}) async {
    puts.add(lists!);
    if (fail) throw Exception("network down");
    stored = lists.toList();
  }
}

class _FakeListApi extends ListApi {
  @override
  Future<List<JsonListItem>> get(Marker m) async => [
        _list(_small, "small"),
        _list(_big, "big"),
        _list(_nsfw, "nsfw"),
      ];

  JsonListItem _list(String id, String variant) => JsonListItem(
        id: id,
        path: "mirror/v5/oisd/$variant/hosts.txt",
        vendor: "oisd",
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

  Future<List<String>> oisd() async {
    final selected = await Core.get<SelectedFilters>().now();
    return selected.firstWhere((it) => it.filterName == "oisd").options;
  }
}

/// Wires the real filter, device and legacy filter actors over fake
/// endpoints, and waits until the device's lists show as selected.
Future<_Subject> _boot(Marker m) async {
  Core.register<StageStore>(MockStageStore());
  Core.register<AccountStore>(MockAccountStore());
  Core.register<EnvActor>(_FakeEnvActor());
  Core.register<AccountActor>(_FakeAccountActor());
  final toast = _RecordingToast();
  Core.register<ToastActor>(toast);

  final api = _FakeDeviceApi();
  Core.register<DeviceApi>(api);
  final device = DeviceStore();
  Core.register<DeviceStore>(device);

  Core.register<ListApi>(_FakeListApi());
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
    test("successfulSaveShowsOneConfirmation", () async {
      await withTrace((m) async {
        final s = await _boot(m);
        expect(await s.oisd(), ["small"]);

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _settle();

        expect(s.api.puts, [
          [_small, _big]
        ]);
        expect(await s.oisd(), ["small", "big"]);
        expect(s.toast.shown, ["toast blocklists saved".i18n]);
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

    test("rapidTogglesSaveOnceWithOneConfirmation", () async {
      await withTrace((m) async {
        final s = await _boot(m);

        await s.actor.toggleFilterOption("oisd", "big", m);
        await _tapGap();
        await s.actor.toggleFilterOption("oisd", "nsfw", m);
        await _settle();

        expect(s.api.puts, hasLength(1));
        expect(s.api.puts.single.toSet(), {_small, _big, _nsfw});
        expect(s.toast.shown, ["toast blocklists saved".i18n]);
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
  });
}
