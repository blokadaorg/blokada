import 'dart:convert';

import 'package:common/device/json.dart';
import 'package:common/env/env.dart';
import 'package:common/http/http.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<HttpService>(),
])
import 'json_test.mocks.dart';

const _fixtureJsonEndpoint = '''{
  "device_tag": "some-tag",
  "lists": ["a", "b"],
  "retention": "24h",
  "paused": true
}''';

void main() {
  String testName = "";
  setUp(() async {
    testName = getTestName();
    await di.reset();
  });

  group("getDevice", () {
    test("willFetchDevice", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final http = MockHttpService();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(_fixtureJsonEndpoint));
        di.registerSingleton<HttpService>(http);

        final subject = DeviceJson();
        final device = await subject.getDevice(trace);

        expect(device.deviceTag, "some-tag");
        expect(device.lists, ["a", "b"]);
        expect(device.retention, "24h");
        expect(device.paused, true);
      });
    });
  });

  group("putDevice", () {
    test("willCreateProperPutRequestForPaused", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final http = MockHttpService();
        when(http.request(any, any, HttpType.put, payload: anyNamed("payload")))
            .thenAnswer((it) =>
                // Check if jsonDecode can parse the payload and if it contains "paused": true
                jsonDecode(it.namedArguments[#payload])["paused"] == true
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        di.registerSingleton<HttpService>(http);

        final subject = DeviceJson();
        await subject.putDevice(trace, paused: true);

        verify(http.request(any, any, HttpType.put,
                payload: anyNamed("payload")))
            .called(1);
      });
    });

    test("willCreateProperPutRequestForRetention", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final http = MockHttpService();
        when(http.request(any, any, HttpType.put, payload: anyNamed("payload")))
            .thenAnswer((it) =>
                // Check if jsonDecode can parse the payload and if it contains retention
                jsonDecode(it.namedArguments[#payload])["retention"] == "1h"
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        di.registerSingleton<HttpService>(http);

        final subject = DeviceJson();
        await subject.putDevice(trace, retention: "1h");

        verify(http.request(any, any, HttpType.put,
                payload: anyNamed("payload")))
            .called(1);
      });
    });

    test("willCreateProperPutRequestForLists", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setAccountId(trace, "some-id");
        di.registerSingleton<EnvStore>(env);

        final http = MockHttpService();
        when(http.request(any, any, HttpType.put, payload: anyNamed("payload")))
            .thenAnswer((it) =>
                // Check if jsonDecode can parse the payload and if it contains lists
                jsonDecode(it.namedArguments[#payload])["lists"][1] == "b"
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        di.registerSingleton<HttpService>(http);

        final subject = DeviceJson();
        await subject.putDevice(trace, lists: ["a", "b"]);

        verify(http.request(any, any, HttpType.put,
                payload: anyNamed("payload")))
            .called(1);
      });
    });
  });
}
