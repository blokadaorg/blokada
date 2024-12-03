import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/http/http.dart';
import 'package:common/platform/journal/json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<HttpService>(),
  MockSpec<AccountStore>(),
])
import 'json_test.mocks.dart';

void main() {
  group("jsonJournalEndpoint", () {
    test("willParseJson", () async {
      await withTrace((m) async {
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
      await withTrace((m) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureJournalEndpoint));
        Core.register<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final subject = JournalJson();
        final entries = await subject.getEntries(m);

        expect(entries.isNotEmpty, true);
        expect(entries.first.domainName, "star.c10r.facebook.com");
      });
    });
  });

  group("errors", () {
    test("willThrowOnInvalidJson", () async {
      await withTrace((m) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value("invalid json"));
        Core.register<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final subject = JournalJson();

        await expectLater(
            subject.getEntries(m), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((m) async {
        await expectLater(
            () => JsonJournalEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
