import 'dart:convert';

import 'package:common/account/account.dart';
import 'package:common/http/http.dart';
import 'package:common/journal/json.dart';
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
  group("jsonJournalEndpoint", () {
    test("willParseJson", () async {
      await withTrace((trace) async {
        final subject =
            JsonJournalEndpoint.fromJson(jsonDecode(fixtureJournalEndpoint));
        final entries = subject.activity;

        expect(entries.isNotEmpty, true);

        final entry = entries.first;

        expect(entry.domainName, "star.c10r.facebook.com");
        expect(entry.deviceName, "deviceName");
        expect(entry.action, "fallthrough");
        expect(entry.timestamp, "2023-05-05T05:50:36.973Z");
      });
    });
  });

  group("getEntries", () {
    test("willFetchEntries", () async {
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureJournalEndpoint));
        depend<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        depend<AccountStore>(account);

        final subject = JournalJson();
        final entries = await subject.getEntries(trace);

        expect(entries.isNotEmpty, true);
        expect(entries.first.domainName, "star.c10r.facebook.com");
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

        final subject = JournalJson();

        await expectLater(
            subject.getEntries(trace), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        await expectLater(
            () => JsonJournalEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
