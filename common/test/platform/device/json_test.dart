import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/device/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Api>(),
  MockSpec<AccountStore>(),
])
import 'json_test.mocks.dart';

const _fixtureJsonEndpoint = '''{
  "device_tag": "some-tag",
  "lists": ["a", "b"],
  "retention": "24h",
  "paused": true,
  "safe_search": false
}''';

void main() {
  group("getDevice", () {
    test("willFetchDevice", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final http = MockApi();
        when(http.get(any, any))
            .thenAnswer((_) => Future.value(_fixtureJsonEndpoint));
        Core.register<Api>(http);

        final subject = DeviceApi();
        final device = await subject.getDevice(m);

        expect(device.deviceTag, "some-tag");
        expect(device.lists, ["a", "b"]);
        expect(device.retention, "24h");
        expect(device.paused, true);
      });
    });
  });

  group("putDevice", () {
    test("willCreateProperPutRequestForPaused", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final http = MockApi();
        when(http.request(any, any, payload: anyNamed("payload"))).thenAnswer(
            (it) =>
                // Check if jsonDecode can parse the payload and if it contains "paused": true
                jsonDecode(it.namedArguments[#payload])["paused"] == true
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        Core.register<Api>(http);

        final subject = DeviceApi();
        await subject.putDevice(m, paused: true);

        verify(http.request(any, any, payload: anyNamed("payload"))).called(1);
      });
    });

    test("willCreateProperPutRequestForRetention", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final http = MockApi();
        when(http.request(ApiEndpoint.putDeviceV2, any,
                payload: anyNamed("payload")))
            .thenAnswer((it) =>
                // Check if jsonDecode can parse the payload and if it contains retention
                jsonDecode(it.namedArguments[#payload])["retention"] == "1h"
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        Core.register<Api>(http);

        final subject = DeviceApi();
        await subject.putDevice(m, retention: "1h");

        verify(http.request(any, any, payload: anyNamed("payload"))).called(1);
      });
    });

    test("willCreateProperPutRequestForLists", () async {
      await withTrace((m) async {
        final account = MockAccountStore();
        when(account.id).thenReturn("some-id");
        Core.register<AccountStore>(account);

        final http = MockApi();
        when(http.request(any, any, payload: anyNamed("payload"))).thenAnswer(
            (it) =>
                // Check if jsonDecode can parse the payload and if it contains lists
                jsonDecode(it.namedArguments[#payload])["lists"][1] == "b"
                    ? Future.value("")
                    : throw Exception(
                        "Bad payload: ${it.namedArguments[#payload]}"));
        Core.register<Api>(http);

        final subject = DeviceApi();
        await subject.putDevice(m, lists: ["a", "b"]);

        verify(http.request(any, any, payload: anyNamed("payload"))).called(1);
      });
    });
  });
}
