import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:common/json/json.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/http/http.dart';
import 'package:common/platform/plus/gateway/json.dart';
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
  group("jsonEndpoint", () {
    test("willParseJson", () async {
      await withTrace((m) async {
        final subject =
            JsonGatewayEndpoint.fromJson(jsonDecode(fixtureGatewayEndpoint));
        final entries = subject.gateways;

        expect(entries.isNotEmpty, true);

        final entry = entries.first;

        expect(entry.region, "europe-west1");
        expect(entry.country, "ES");
      });
    });
  });

  group("getEntries", () {
    test("willFetchEntries", () async {
      await withTrace((m) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureGatewayEndpoint));
        depend<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        depend<AccountStore>(account);

        final subject = PlusGatewayJson();
        final entries = await subject.get(m);

        expect(entries.isNotEmpty, true);
        expect(entries.first.region, "europe-west1");
      });
    });
  });

  group("errors", () {
    test("willThrowOnInvalidJson", () async {
      await withTrace((m) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value("invalid json"));
        depend<HttpService>(http);

        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        depend<AccountStore>(account);

        final subject = PlusGatewayJson();

        await expectLater(subject.get(m), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((m) async {
        await expectLater(
            () => JsonGatewayEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
