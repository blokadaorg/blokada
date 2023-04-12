import 'package:common/custom/channel.pg.dart';
import 'package:common/custom/custom.dart';
import 'package:common/custom/json.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<CustomStore>(),
  MockSpec<CustomOps>(),
  MockSpec<CustomJson>(),
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
  });

  group("binder", () {
    test("onAllowAndOthers", () async {
      await withTrace((trace) async {
        final store = MockCustomStore();
        di.registerSingleton<CustomStore>(store);

        final subject = CustomBinder.forTesting();

        await subject.onAllow("test.com");
        verify(store.allow(any, "test.com")).called(1);

        await subject.onDeny("test.com");
        verify(store.deny(any, "test.com")).called(1);

        await subject.onDelete("test.com");
        verify(store.delete(any, "test.com")).called(1);
      });
    });
  });
}
