import 'package:common/deck/deck.dart';
import 'package:common/deck/channel.pg.dart';
import 'package:common/deck/json.dart';
import 'package:common/device/device.dart';
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
  });

  group("binder", () {
    test("onEnableList", () async {
      await withTrace((trace) async {
        final store = MockDeckStore();
        di.registerSingleton<DeckStore>(store);

        final subject = DeckBinder.forTesting();
        await subject.onEnableList("1", true);
        verify(store.setEnableList(any, "1", true)).called(1);
      });
    });

    test("onDeviceLists", () async {
      await withTrace((trace) async {
        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final store = MockDeckStore();
        di.registerSingleton<DeckStore>(store);

        final subject = DeckBinder.forTesting();
        device.lists = ["1", "6"];
        verify(store.setUserLists(any, ["1", "6"])).called(1);
      });
    });

    test("onDecksChanged", () async {
      await withTrace((trace) async {
        final json = MockDeckJson();
        when(json.getLists(any))
            .thenAnswer((_) => Future.value(fixtureListItems));
        di.registerSingleton<DeckJson>(json);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final ops = MockDeckOps();
        di.registerSingleton<DeckOps>(ops);

        final store = DeckStore();
        di.registerSingleton<DeckStore>(store);

        final subject = DeckBinder.forTesting();
        await store.fetch(trace);
        verify(ops.doDecksChanged(any)).called(1);

        await store.setEnableList(trace, "1", true);
        verify(ops.doDecksChanged(any)).called(1);
      });
    });
  });
}
