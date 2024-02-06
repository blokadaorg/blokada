import 'dart:async';

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

        final subject = FilterActor(act);
        subject.injectApi((it) async {
          subject.apiOk(fixtureListEndpoint);
        });
        subject.injectPutUserLists((it) async {});

        subject.userLists({});
        final c = await subject.waitForState("ready");

        expect(
            c.selectedFilters.where((it) => it.options.isNotEmpty).length, 1);
      });
    });

    test("defaults", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(act);
        subject.injectApi((it) async {
          subject.apiOk(fixtureListEndpoint);
        });

        final c = Completer<void>();
        subject.injectPutUserLists((it) async {
          if (it.length == 1) c.complete();
        });

        subject.userLists({"1"});

        await subject.waitForState("ready");
        await c.future;
      });
    });

    test("listsToTags", () async {
      await withTrace((trace) async {
        final act = ActScreenplay(
            ActScenario.platformIsMocked, Flavor.og, Platform.ios);

        final subject = FilterActor(act);
        subject.injectApi((it) async {
          subject.apiOk(fixtureListEndpoint);
        });

        subject.injectPutUserLists((it) async {});

        subject.userLists({"1"});

        final c = await subject.waitForState("ready");

        expect(
            c.listsToTags["03489ad60c13b83a55203c804a1567df"], "1hosts/litea");
      });
    });
  });
}
