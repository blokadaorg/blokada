import 'dart:convert';

import 'package:common/custom/json.dart';
import 'package:common/env/env.dart';
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
])
import 'json_test.mocks.dart';

void main() {
  group("jsonEndpoint", () {
    test("willParseJson", () async {
      await withTrace((trace) async {
        final subject =
            JsonCustomEndpoint.fromJson(jsonDecode(fixtureCustomEndpoint));
        final entries = subject.customList;

        expect(entries.isNotEmpty, true);

        final entry = entries.first;

        expect(entry.domainName, "bad.actor.is.bad.com");
        expect(entry.action, "block");
      });
    });
  });

  group("getEntries", () {
    test("willFetchEntries", () async {
      await withTrace((trace) async {
        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(fixtureCustomEndpoint));
        di.registerSingleton<HttpService>(http);

        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final subject = CustomJson();
        final entries = await subject.getEntries(trace);

        expect(entries.isNotEmpty, true);
        expect(entries.first.domainName, "bad.actor.is.bad.com");
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

        final subject = CustomJson();

        await expectLater(
            subject.getEntries(trace), throwsA(isA<FormatException>()));
      });
    });

    test("fromJsonWillThrowOnInvalidJson", () async {
      await withTrace((trace) async {
        await expectLater(
            () => JsonCustomEndpoint.fromJson({}), throwsA(isA<JsonError>()));
      });
    });
  });
}
