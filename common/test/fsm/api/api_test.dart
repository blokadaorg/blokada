import 'dart:async';

import 'package:common/fsm/api/api.dart';
import 'package:common/fsm/machine.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';
// @GenerateNiceMocks([
//   MockSpec<HttpService>(),
//   MockSpec<AccountStore>(),
// ])

void main() {
  group("ApiActor", () {
    test("basic", () async {
      await withTrace((trace) async {
        final subject = ApiActor(mockedAct);
        subject.injectHttp((it) async {
          subject.httpOk("result");
        });
        subject.queryParams({});

        subject.request(const HttpRequest(url: "https://example.com/"));
        final result = await subject.waitForState("success");
        expect(result.result, "result");
      });
    });

    test("failingRequest", () async {
      await withTrace((trace) async {
        final error = Exception("error");
        final subject = ApiActor(mockedAct);
        subject.injectHttp((it) async {
          subject.httpFail(error);
        });
        await subject.queryParams({});

        await subject.request(const HttpRequest(url: "https://example.com/"));
        try {
          final result = await subject.waitForState("success");
          expect(result.error, error);
        } catch (e) {}
      });
    });

    test("queryParams", () async {
      await withTrace((trace) async {
        final subject = ApiActor(mockedAct);
        subject.injectHttp((it) async {
          subject.httpOk("result");
        });
        await subject.queryParams({"account_id": "test"});

        await subject.apiRequest(ApiEndpoint.getList);
        final result = await subject.waitForState("success");
        expect(result.result, "result");
      });
    });

    test("queryParamsMissing", () async {
      await withTrace((trace) async {
        final subject = ApiActor(mockedAct);
        subject.injectHttp((it) async {
          subject.httpOk("result");
        });
        await subject.queryParams({});

        await subject.apiRequest(ApiEndpoint.getList);
        await expectLater(subject.waitForState("success"), throws);
      });
    });

    test("apiRequest2", () async {
      await withTrace((trace) async {
        final subject = ApiActor(mockedAct);
        subject.injectHttp((it) async {
          subject.httpOk("result");
        });
        await subject.queryParams({});

        await subject.waitForState("ready");
        await subject.apiRequest(ApiEndpoint.getList);
        await expectLater(subject.waitForState("success"), throws);
      });
    });
  });

  test("whenState", () async {
    await withTrace((trace) async {
      final subject = ApiActor(mockedAct);
      subject.injectHttp((it) async {
        subject.httpOk("result");
      });
      subject.queryParams({});

      final c = Completer<void>();
      subject.whenState("success", (_) {
        c.complete();
      });

      subject.request(const HttpRequest(url: "https://example.com/"));
      await c.future;
    });
  });
}
