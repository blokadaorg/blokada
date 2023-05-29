import 'dart:convert';

import 'package:common/env/env.dart';
import 'package:common/http/http.dart';
import 'package:common/json/json.dart';
import 'package:common/plus/lease/json.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<HttpService>(),
])
import 'json_test.mocks.dart';

void main() {
  group("jsonEndpoint", () {
    test("willParseJson", () async {
      await withTrace((trace) async {
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
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureLeaseEndpoint));
        di.registerSingleton<HttpService>(http);

        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final subject = PlusLeaseJson();
        final entries = await subject.getLeases(trace);

        expect(entries.isNotEmpty, true);
        expect(entries.first.alias, "Solar quokka");
      });
    });
  });

  group("errors", () {
    test("willThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value("invalid json"));
        di.registerSingleton<HttpService>(http);

        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final subject = PlusLeaseJson();

        await expectLater(
            subject.getLeases(trace), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        await expectLater(
            () => JsonLeaseEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
