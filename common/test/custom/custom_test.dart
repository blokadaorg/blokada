import 'package:common/custom/channel.pg.dart';
import 'package:common/custom/custom.dart';
import 'package:common/custom/json.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<CustomStore>(),
  MockSpec<CustomOps>(),
  MockSpec<CustomJson>(),
  MockSpec<StageStore>(),
])
import 'custom_test.mocks.dart';
import 'fixtures.dart';

void main() {
  group("store", () {
    test("willSplitEntriesByType", () async {
      await withTrace((trace) async {
        final json = MockCustomJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureCustomEntries));
        di.registerSingleton<CustomJson>(json);

        final ops = MockCustomOps();
        depend<CustomOps>(ops);

        final subject = CustomStore();
        await subject.fetch(trace);

        expect(subject.allowed.length, 3);
        expect(subject.allowed.first, "abc.example.com");
        expect(subject.denied.length, 4);
        expect(subject.denied.first, "abc.sth.io");
      });
    });

    test("allowAndOthers", () async {
      await withTrace((trace) async {
        final json = MockCustomJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureCustomEntries));
        di.registerSingleton<CustomJson>(json);

        final ops = MockCustomOps();
        depend<CustomOps>(ops);

        final subject = CustomStore();

        // Will post entry and refresh
        await subject.allow(trace, "test.com");
        verify(json.postEntry(any, any)).called(1);
        verify(json.getEntries(any)).called(1);

        await subject.deny(trace, "test.com");
        verify(json.postEntry(any, any)).called(1);
        verify(json.getEntries(any)).called(1);

        await subject.delete(trace, "test.com");
        verify(json.deleteEntry(any, any)).called(1);
        verify(json.getEntries(any)).called(1);
      });
    });

    test("willRefreshWhenNeeded", () async {
      await withTrace((trace) async {
        final json = MockCustomJson();
        di.registerSingleton<CustomJson>(json);

        final stage = MockStageStore();
        when(stage.isForeground).thenReturn(true);
        when(stage.route).thenReturn(StageRoute.forTab(StageTab.activity));
        depend<StageStore>(stage);

        final ops = MockCustomOps();
        depend<CustomOps>(ops);

        final subject = CustomStore();
        verifyNever(json.getEntries(any));

        // Initially will refresh
        await subject.maybeRefreshCustom(trace);
        verify(json.getEntries(any));

        // Then it wont refresh (until cooldown time passed)
        await subject.maybeRefreshCustom(trace);
        verifyNever(json.getEntries(any));

        // Imagine cooldown passed, should refresh again
        subject.lastRefresh =
            DateTime.now().subtract(const Duration(seconds: 10));
        await subject.maybeRefreshCustom(trace);
        verify(json.getEntries(any));
      });
    });
  });
}
