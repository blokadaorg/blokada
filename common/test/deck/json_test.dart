import 'dart:convert';

import 'package:common/account/account.dart';
import 'package:common/fsm/filter/json.dart';
import 'package:common/http/http.dart';
import 'package:common/json/json.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<HttpService>(),
  MockSpec<AccountStore>(),
])
import 'json_test.mocks.dart';

void main() {
  group("jsonListEndpoint", () {
    test("willParseJson", () async {
      await withTrace((trace) async {
        final subject =
            JsonListEndpoint.fromJson(jsonDecode(fixtureListEndpoint));
        final items = subject.lists;

        expect(items.isNotEmpty, true);

        final entry = items.first;

        expect(entry.path, "mirror/v5/1hosts/litea/hosts.txt");
        expect(entry.managed, true);
      });
    });
  });

  group("getLists", () {
    test("willFetchLists", () async {
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureListEndpoint));
        depend<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        depend<AccountStore>(account);

        final subject = DeckJson();
        final entries = await subject.getLists(trace);

        expect(entries.isNotEmpty, true);
        expect(entries.first.path, "mirror/v5/1hosts/litea/hosts.txt");
      });
    });
  });

  group("errors", () {
    test("willThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value("invalid json"));
        depend<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        depend<AccountStore>(account);

        final subject = DeckJson();

        await expectLater(
            subject.getLists(trace), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        await expectLater(
            () => JsonListEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
