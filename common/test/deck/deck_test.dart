import 'package:common/deck/deck.dart';
import 'package:common/deck/channel.pg.dart';
import 'package:common/deck/json.dart';
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
        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        di.registerSingleton<DeckJson>(json);

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
        expect(f.items["1"]?.tag, "litea");
        expect(f.items["2"]?.id, "2");
        expect(f.items["2"]?.tag, "lite (wildcards)");
        expect(f.items["5"]?.id, "5");
        expect(f.items["5"]?.tag, "lite");
        expect(decks.elementAt(1).items["3"]?.id, "3");
        expect(decks.elementAt(1).items["3"]?.tag, "spotify");
      });
    });

    test("setUserLists", () async {
      await withTrace((trace) async {
        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        di.registerSingleton<DeckJson>(json);

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
        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        di.registerSingleton<DeckJson>(json);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

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
        final ops = MockDeckOps();
        depend<DeckOps>(ops);

        final json = MockDeckJson();
        di.registerSingleton<DeckJson>(json);

        final stage = MockStageStore();
        when(stage.isForeground).thenReturn(true);
        when(stage.route).thenReturn(StageRoute.forTab(StageTab.advanced));
        depend<StageStore>(stage);

        final subject = DeckStore();
        verifyNever(json.getLists(any));

        // Initially will refresh
        await subject.maybeRefreshDeck(trace);
        verify(json.getLists(any));

        // Then it wont refresh (until cooldown time passed)
        await subject.maybeRefreshDeck(trace);
        verifyNever(json.getLists(any));

        // Imagine cooldown passed, should refresh again
        subject.lastRefresh =
            DateTime.now().subtract(const Duration(minutes: 10));
        await subject.maybeRefreshDeck(trace);
        verify(json.getLists(any));
      });
    });
  });
}
