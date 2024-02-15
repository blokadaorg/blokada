import 'dart:async';

import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model.dart';
import 'package:common/common/model/filter/filter_json.dart';
import 'package:common/fsm/api/api.dart';
import 'package:common/fsm/filter/filter.dart';
import 'package:common/fsm/machine.dart';
import 'package:common/tracer/collectors.dart';
import 'package:common/tracer/tracer.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../deck/fixtures.dart';
import '../../tools.dart';

void main() {
  group("filter", () {
    test("basic", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(
            actionLists: (_) async => DeckJson().lists(fixtureListEndpoint),
            actionPutUserLists: (it) async {},
            actionPutConfig: (_) async {},
            actionKnownFilters: (_) async => getKnownFilters(act),
            actionDefaultEnabled: (_) async => getDefaultEnabled(act));

        await subject.config({}, {});
        final c = await subject.waitForState(FilterStates.ready);

        expect(
            c.selectedFilters.where((it) => it.options.isNotEmpty).length, 1);
      });
    });

    test("directOnStates", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final c = TestFilterContext();
        c.injectActionLists =
            (_) async => DeckJson().lists(fixtureListEndpoint);
        c.injectActionKnownFilters = (_) async => getKnownFilters(act);

        await FilterStates.reload(c);
        expect(c.listsToTags.length, 14);

        c.injectSelectedLists = {
          "2034b164ce8e64953de05746a2aa836a",
          "3309fb926cecf32de027dce2e4871a6e",
        };
        await FilterStates.parse(c);
        final selected = c.selectedFilters.where((it) => it.options.isNotEmpty);

        expect(selected.length, 2);
        expect(selected.first.filterName, "oisd");
        expect(selected.first.options, ["small"]);
        expect(selected.skip(1).first.filterName, "blocklist");
        expect(selected.skip(1).first.options, ["phishing"]);
      });
    });

    test("defaults", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final c = Completer<void>();
        final subject = FilterActor(
            actionLists: (_) async => DeckJson().lists(fixtureListEndpoint),
            actionPutConfig: (_) async {},
            actionPutUserLists: (it) async {
              if (it.length == 1) c.complete();
            },
            actionKnownFilters: (_) async => getKnownFilters(act),
            actionDefaultEnabled: (_) async => getDefaultEnabled(act));

        await subject.config({}, {});
        await subject.waitForState(FilterStates.ready);
        await c.future;
      });
    });

    test("listsToTags", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(
            actionLists: (_) async => DeckJson().lists(fixtureListEndpoint),
            actionPutConfig: (_) async {},
            actionPutUserLists: (it) async {},
            actionKnownFilters: (_) async => getKnownFilters(act),
            actionDefaultEnabled: (_) async => getDefaultEnabled(act));

        await subject.config({"1"}, {});
        final c = await subject.waitForState(FilterStates.ready);

        expect(
            c.listsToTags["03489ad60c13b83a55203c804a1567df"], "1hosts/litea");
      });
    });

    test("enableFilter", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(
            actionLists: (_) async => DeckJson().lists(fixtureListEndpoint),
            actionPutConfig: (_) async {},
            actionPutUserLists: (it) async {},
            actionKnownFilters: (_) async => getKnownFilters(act),
            actionDefaultEnabled: (_) async => getDefaultEnabled(act));

        await subject.config({"1"}, {});
        var c = await subject.waitForState(FilterStates.ready);

        expect(c.selectedFilters.length, 1); // Because defaults

        await subject.enableFilter("1hosts", true);
        c = await subject.waitForState(FilterStates.ready);

        expect(c.selectedFilters.length, 2);
      });
    });

    test("resetConfig", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(
            actionLists: (_) async => DeckJson().lists(fixtureListEndpoint),
            actionPutConfig: (_) async {},
            actionPutUserLists: (it) async {},
            actionKnownFilters: (_) async => getKnownFilters(act),
            actionDefaultEnabled: (_) async => getDefaultEnabled(act));

        await subject.config({
          "33b3bc8d3a16d5642c1c45ec38979d7c",
          "3309fb926cecf32de027dce2e4871a6e"
        }, {});
        var c = await subject.waitForState(FilterStates.ready);
        expect(
            c.selectedFilters.where((it) => it.options.isNotEmpty).length, 2);

        await subject.enter(FilterStates.clearConfig);
        c = await subject.waitForState(FilterStates.waitForConfig);

        await subject.config({}, {});
        c = await subject.waitForState(FilterStates.ready);

        // Reverted to defaults
        expect(
            c.selectedFilters.where((it) => it.options.isNotEmpty).length, 1);
      });
    });
  });
}
