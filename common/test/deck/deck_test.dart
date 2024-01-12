import 'package:common/deck/deck.dart';
import 'package:common/deck/channel.pg.dart';
import 'package:common/fsm/filter/json.dart';
import 'package:common/deck/mapper.dart';
import 'package:common/device/device.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<DeckStore>(),
  MockSpec<DeckOps>(),
  MockSpec<DeckJson>(),
  MockSpec<DeviceStore>(),
  MockSpec<StageStore>(),
])
import 'deck_test.mocks.dart';
import 'fixtures.dart';

void main() {
  group("store", () {
    test("willFetchDecks", () async {
      await withTrace((trace) async {
        depend<DeckMapper>(CloudDeckMapper());
        depend<StageStore>(MockStageStore());
        depend<DeviceStore>(MockDeviceStore());

        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        depend<DeckJson>(json);

        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final subject = DeckStore();
        await subject.fetch(trace);

        final decks = subject.decks.values;
        final f = decks.first;
        expect(decks.length, 4);
        expect(f.items.length, 3);
        expect(f.deckId, "1hosts");
        expect(f.enabled, false);
        expect(f.items["1"]?.id, "1");
        expect(f.items["1"]?.tag, "1hosts/litea");
        expect(f.items["2"]?.id, "2");
        expect(f.items["2"]?.tag, "1hosts/lite (wildcards)");
        expect(f.items["5"]?.id, "5");
        expect(f.items["5"]?.tag, "1hosts/lite");
        expect(decks.elementAt(1).items["3"]?.id, "3");
        expect(decks.elementAt(1).items["3"]?.tag, "goodbyeads/spotify");
      });
    });

    test("setUserLists", () async {
      await withTrace((trace) async {
        depend<DeckMapper>(CloudDeckMapper());
        depend<StageStore>(MockStageStore());
        depend<DeviceStore>(MockDeviceStore());

        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        depend<DeckJson>(json);

        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final subject = DeckStore();
        await subject.fetch(trace);

        // A list of enabled list-ids coming from the backend
        await subject.setUserLists(trace, ["1", "6"]);

        final decks = subject.decks.values;
        expect(decks.first.enabled, true);
        expect(decks.first.items.values.first?.enabled ?? false, true);
        expect(decks.last.enabled, true);
      });
    });

    test("setEnableList", () async {
      await withTrace((trace) async {
        depend<DeckMapper>(CloudDeckMapper());
        depend<StageStore>(MockStageStore());

        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        depend<DeckJson>(json);

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final subject = DeckStore();
        await subject.fetch(trace);

        // User enables one list
        await subject.setEnableList(trace, "1", true);

        final decks = subject.decks.values;
        expect(decks.first.enabled, true);
        expect(decks.first.items.values.first?.enabled ?? false, true);
      });
    });

    test("willRefreshWhenNeeded", () async {
      await withTrace((trace) async {
        depend<DeckMapper>(CloudDeckMapper());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final json = MockDeckJson();
        depend<DeckJson>(json);

        final route = StageRouteState.init().newTab(StageTab.advanced);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        depend<StageStore>(stage);

        final subject = DeckStore();
        verifyNever(json.getLists(any));

        await subject.onRouteChanged(trace, route);
        verify(json.getLists(any));
      });
    });

    // test("willSelectDefaultWhenEmpty", () async {
    //   await withTrace((trace) async {
    //     depend<StageStore>(MockStageStore());
    //
    //     final device = MockDeviceStore();
    //     when(device.lists).thenReturn([]);
    //     depend<DeviceStore>(device);
    //
    //     final ops = MockDeckOps();
    //     depend<DeckOps>(ops);
    //
    //     final json = MockDeckJson();
    //     depend<DeckJson>(json);
    //
    //     final subject = DeckStore();
    //     mockAct(subject);
    //     verifyNever(device.setLists(any, any));
    //
    //     await subject.onDeviceChanged(trace);
    //     verify(device.setLists(any, any));
    //   });
    // });
  });
}
