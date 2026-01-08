import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<Api>(),
])
import 'json_test.mocks.dart';

void main() {
  group("getAccount", () {
    test("willFetchAccount", () async {
      await withTrace((m) async {
        final http = MockApi();
        when(http.get(any, any, params: anyNamed("params")))
            .thenAnswer((_) => Future.value(fixtureJsonEndpoint));
        Core.register<Api>(http);

        final subject = AccountApi();
        final account = await subject.getAccount("some-id", m);

        expect(account.type, "cloud");
        expect(account.active, true);
        expect(account.activeUntil, "2023-01-23T06:46:37.790654Z");
      });
    });
  });

  group("postAccount", () {
    test("willCallPostMethod", () async {
      await withTrace((m) async {
        final http = MockApi();
        when(http.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams")))
            .thenAnswer((_) => Future.value(fixtureJsonEndpoint));
        Core.register<Api>(http);

        final subject = AccountApi();
        final account = await subject.postAccount(m);

        verify(http.request(any, any, skipResolvingParams: true)).called(1);
        expect(account.id, "mockedmocked");
      });
    });
  });

  group("jsonAccount", () {
    test("willParseJson", () async {
      await withTrace((m) async {
        final subject = JsonAccount.fromJson(jsonDecode(fixtureJsonAccount));

        expect(subject.id, "mockedmocked");
        expect(subject.activeUntil, "2023-01-23T06:46:37.790654Z");
        expect(subject.active, true);
        expect(subject.type, "cloud");
        expect(subject.paymentSource, "internal");
        expect(subject.isActive(), true);

        final json = subject.toJson();

        expect(json["id"], "mockedmocked");
        expect(json["active_until"], "2023-01-23T06:46:37.790654Z");
        expect(json["active"], true);
        expect(json["type"], "cloud");
        expect(json["payment_source"], "internal");
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

        final subject = AccountApi();

        await expectLater(
            subject.getAccount("some-id", m), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((m) async {
        await expectLater(
            () => JsonAccount.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
