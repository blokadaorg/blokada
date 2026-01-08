import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/features/plus/domain/lease/lease.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<Api>(),
  MockSpec<AccountStore>(),
])
import 'json_test.mocks.dart';

void main() {
  group("jsonEndpoint", () {
    test("willParseJson", () async {
      await withTrace((m) async {
        final subject =
            JsonLeaseEndpoint.fromJson(jsonDecode(fixtureLeaseEndpoint));
        final entries = subject.leases;

        expect(entries.isNotEmpty, true);

        final entry = entries.first;

        expect(entry.vip4, "10.143.0.142");
        expect(entry.alias, "Solar quokka");
      });
    });
  });

  group("getEntries", () {
    test("willFetchEntries", () async {
      await withTrace((m) async {
        final http = MockApi();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureLeaseEndpoint));
        Core.register<Api>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final subject = LeaseApi();
        final entries = await subject.getLeases(m);

        expect(entries.isNotEmpty, true);
        expect(entries.first.alias, "Solar quokka");
      });
    });
  });

  group("errors", () {
    test("willThrowOnInvalidJson", () async {
      await withTrace((m) async {
        final http = MockApi();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value("invalid json"));
        Core.register<Api>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final subject = LeaseApi();

        await expectLater(
            subject.getLeases(m), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((m) async {
        await expectLater(
            () => JsonLeaseEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
