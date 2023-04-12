import 'package:common/http/channel.pg.dart';
import 'package:common/http/http.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<HttpOps>(),
  MockSpec<HttpService>(),
])
import 'http_test.mocks.dart';

void main() {
  group("PlatformHttpService", () {
    test("get", () async {
      await withTrace((trace) async {
        final ops = MockHttpOps();
        when(ops.doGet(any)).thenAnswer((_) => Future.value("some-response"));
        di.registerSingleton<HttpOps>(ops);

        final subject = PlatformHttpService();

        final response = await subject.get(trace, "some-url");
        expect(response, "some-response");
      });
    });

    test("postOrPut", () async {
      await withTrace((trace) async {
        final ops = MockHttpOps();
        when(ops.doRequest(any, any, any))
            .thenAnswer((_) => Future.value("some-response"));
        di.registerSingleton<HttpOps>(ops);

        final subject = PlatformHttpService();

        await subject.request(trace, "some-url", HttpType.post,
            payload: "some-payload");
        verify(ops.doRequest(any, "some-payload", "post")).called(1);

        await subject.request(trace, "some-url", HttpType.put);
        verify(ops.doRequest(any, any, "put")).called(1);
      });
    });

    test("errorIsPropagated", () async {
      await withTrace((trace) async {
        final ops = MockHttpOps();
        when(ops.doGet(any)).thenThrow(Exception("some-error"));
        when(ops.doRequest(any, any, any))
            .thenThrow(ArgumentError("not-exception"));
        di.registerSingleton<HttpOps>(ops);

        final subject = PlatformHttpService();

        await expectLater(subject.get(trace, "some-url"), throwsException);
        await expectLater(subject.request(trace, "some-url", HttpType.put),
            throwsArgumentError);
      });
    });
  });

  group("RepeatingHttpService", () {
    test("getWillRetryOnFailure", () async {
      await withTrace((trace) async {
        final service = MockHttpService();
        // First two calls will fail, third will succeed
        int callCounter = 0;
        when(service.get(any, any)).thenAnswer((_) => callCounter++ < 2
            ? Future.error(Exception("some-error"))
            : Future.value("some-response"));
        di.registerSingleton<HttpService>(service);

        final subject = RepeatingHttpService(service,
            maxRetries: 1, waitTime: Duration.zero);

        // First call will fail, second also, so it should return error
        await expectLater(subject.get(trace, "some-url"), throwsException);

        // Now this will be the third call, so it should succeed
        final response = await subject.get(trace, "some-url");
        expect(response, "some-response");
        verify(service.get(any, any)).called(3);
      });
    });

    test("postOrPutWillRetryOnFailure", () async {
      await withTrace((trace) async {
        final service = MockHttpService();
        int callCounter = 0;
        when(service.request(any, any, any)).thenAnswer((_) => callCounter++ < 1
            ? Future.error(Exception("some-error"))
            : Future.value("some-response"));
        di.registerSingleton<HttpService>(service);

        final subject = RepeatingHttpService(service,
            maxRetries: 1, waitTime: Duration.zero);

        // TODO: handle HttpCodeException
        // TODO: post / put should only repeat on some errors (e.g. 500)
        final response = await subject.request(trace, "some-url", HttpType.put);
        expect(response, "some-response");
        verify(service.request(any, any, any)).called(2);
      });
    });
  });
}
