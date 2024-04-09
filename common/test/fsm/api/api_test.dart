// import 'dart:async';
//
// import 'package:common/via/fsm/api/api.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// import '../../tools.dart';
// // @GenerateNiceMocks([
// //   MockSpec<HttpService>(),
// //   MockSpec<AccountStore>(),
// // ])
//
// void main() {
//   group("ApiActor", () {
//     test("basic", () async {
//       await withTrace((trace) async {
//         final subject = ApiActor(
//           actionHttp: (it) async => "result",
//           actionSleep: (it) async {},
//         );
//
//         subject.config("https://example.com/", {});
//         subject.request(HttpRequest(ApiEndpoint.getGateways));
//
//         final result = await subject.waitForState(ApiStates.success);
//         expect(result.result, "result");
//       });
//     });
//
//     test("failingRequest", () async {
//       await withTrace((trace) async {
//         final error = Exception("error");
//
//         final subject = ApiActor(
//           actionHttp: (it) async => throw error,
//           actionSleep: (it) async {},
//         );
//
//         subject.config("https://example.com/", {});
//         subject.request(HttpRequest(ApiEndpoint.getGateways));
//
//         await expectLater(
//             subject.waitForState(ApiStates.success), throwsA(error));
//       });
//     });
//
//     test("queryParams", () async {
//       await withTrace((trace) async {
//         final subject = ApiActor(
//           actionHttp: (it) async => "result",
//           actionSleep: (it) async {},
//         );
//
//         subject.config("https://example.com/", {ApiParam.accountId: "test"});
//         subject.request(HttpRequest(ApiEndpoint.getLists));
//
//         final result = await subject.waitForState(ApiStates.success);
//         expect(result.result, "result");
//       });
//     });
//
//     test("queryParamsMissing", () async {
//       await withTrace((trace) async {
//         final subject = ApiActor(
//           actionHttp: (it) async => "result",
//           actionSleep: (it) async {},
//         );
//
//         subject.config("https://example.com/", {});
//         subject.request(HttpRequest(ApiEndpoint.getLists));
//
//         await expectLater(subject.waitForState(ApiStates.success), throws);
//       });
//     });
//
//     test("whenState", () async {
//       await withTrace((trace) async {
//         final subject = ApiActor(
//           actionHttp: (it) async => "result",
//           actionSleep: (it) async {},
//         );
//
//         subject.config("https://example.com/", {});
//         subject.request(HttpRequest(ApiEndpoint.getGateways));
//
//         final c = Completer<void>();
//         subject.whenState(ApiStates.success, (_) {
//           c.complete();
//         });
//
//         await c.future;
//       });
//     });
//   });
// }
