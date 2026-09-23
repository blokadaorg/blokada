import 'dart:async';

import 'package:common/src/app_variants/v6/module/attach/attach.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/config/domain/config.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Api>(),
  MockSpec<StageStore>(),
  MockSpec<ConfigChannel>(),
])
import 'attach_actor_test.mocks.dart';

const _url = "https://app.blokada.org/link#token=";

void main() {
  group("AttachActor", () {
    test("opens the hand-off link in the browser", () async {
      await withTrace((m) async {
        _registerApiReturning(["token-one"]);
        final stage = _registerStage();
        final config = _registerConfig();

        await AttachActor().openInBrowser(m);

        verify(stage.openUrl("${_url}token-one", any)).called(1);
        verifyNever(config.doShareText(any));
      });
    });

    test("shares the hand-off link without opening it here", () async {
      await withTrace((m) async {
        _registerApiReturning(["token-one"]);
        final stage = _registerStage();
        final config = _registerConfig();

        await AttachActor().share(m);

        verify(config.doShareText("${_url}token-one")).called(1);
        verifyNever(stage.openUrl(any, any));
      });
    });

    test("mints a fresh token for every tap", () async {
      await withTrace((m) async {
        final api = _registerApiReturning(["token-one", "token-two"]);
        final stage = _registerStage();
        _registerConfig();

        final actor = AttachActor();
        await actor.openInBrowser(m);
        await actor.openInBrowser(m);

        // A token is single use and expires in 5 minutes, so a cached one
        // would send the second device to an "already used" page.
        verify(api.request(any, any, payload: anyNamed("payload"), attempts: 1)).called(2);
        verify(stage.openUrl("${_url}token-one", any)).called(1);
        verify(stage.openUrl("${_url}token-two", any)).called(1);
      });
    });

    test("ignores a tap while another link is still being created", () async {
      await withTrace((m) async {
        final api = MockApi();
        final pending = Completer<String>();
        when(api.request(any, any, payload: anyNamed("payload"), attempts: 1))
            .thenAnswer((_) => pending.future);
        Core.register<Api>(api);
        Core.register<AttachApi>(AttachApi());

        final stage = _registerStage();
        _registerConfig();

        final actor = AttachActor();
        final first = actor.openInBrowser(m);
        final second = actor.openInBrowser(m);
        pending.complete(_response("token-one"));
        await Future.wait([first, second]);

        verify(api.request(any, any, payload: anyNamed("payload"), attempts: 1)).called(1);
        verify(stage.openUrl("${_url}token-one", any)).called(1);
      });
    });

    test("rethrows a rejected creation and opens nothing", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any, payload: anyNamed("payload"), attempts: 1))
            .thenThrow(HttpCodeException(403, "account not active"));
        Core.register<Api>(api);
        Core.register<AttachApi>(AttachApi());

        final stage = _registerStage();
        final config = _registerConfig();

        // The sheet turns this into an error dialog, so it must not be
        // swallowed here.
        await expectLater(
            AttachActor().openInBrowser(m), throwsA(isA<HttpCodeException>()));

        verifyNever(stage.openUrl(any, any));
        verifyNever(config.doShareText(any));
      });
    });

    test("stays usable after a failed creation", () async {
      await withTrace((m) async {
        final api = MockApi();
        var failed = false;
        when(api.request(any, any, payload: anyNamed("payload"), attempts: 1))
            .thenAnswer((_) async {
          if (failed) return _response("token-one");
          failed = true;
          throw HttpCodeException(500, "server error");
        });
        Core.register<Api>(api);
        Core.register<AttachApi>(AttachApi());

        final stage = _registerStage();
        _registerConfig();

        final actor = AttachActor();
        await expectLater(
            actor.openInBrowser(m), throwsA(isA<HttpCodeException>()));

        // The in-flight guard must be released on failure, or one bad network
        // moment would lock the feature until the app restarts.
        await actor.openInBrowser(m);

        verify(stage.openUrl("${_url}token-one", any)).called(1);
      });
    });
  });
}

MockApi _registerApiReturning(List<String> tokens) {
  final api = MockApi();
  var next = 0;
  when(api.request(any, any, payload: anyNamed("payload"), attempts: 1))
      .thenAnswer((_) async => _response(tokens[next++]));
  Core.register<Api>(api);
  Core.register<AttachApi>(AttachApi());
  return api;
}

MockStageStore _registerStage() {
  final stage = MockStageStore();
  Core.register<StageStore>(stage);
  return stage;
}

MockConfigChannel _registerConfig() {
  final config = MockConfigChannel();
  Core.register<ConfigChannel>(config);
  return config;
}

String _response(String token) => '''{
  "token": "$token",
  "expires": "2026-09-22T10:05:00Z",
  "expires_in": 300
}''';
