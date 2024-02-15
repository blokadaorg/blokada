import 'dart:async';

import 'package:common/fsm/api/api.dart';
import 'package:common/fsm/device/json.dart';
import 'package:common/http/channel.pg.dart';
import 'package:common/util/di.dart';
import 'package:common/via/api/api.dart';
import 'package:common/via/device/device.dart';
import 'package:common/via/device/generator.dart';
import 'package:common/via/persistence/persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:vistraced/via.dart';

import '../tools.dart';
import 'via_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<HttpOps>(),
  MockSpec<AccountId>(),
])
void main() {
  group("Via", () {
    test("basic", () async {
      await withTrace((trace) async {
        final module = ApiModule();
        injector.register<Act>(mockedAct);

        final id = MockAccountId();
        when(id.get()).thenReturn("test");
        injector.register<AccountId>(id);

        final ops = MockHttpOps();
        injector.register<HttpOps>(ops);
        when(ops.doGet(any)).thenAnswer((_) async => "dupa");
        injector.inject();

        final Http http = injector.get();

        final result = await http.call(HttpRequest(ApiEndpoint.getDevices));

        expect(result, "dupa");
      });
    });

    //   test("deep", () async {
    //     await withTrace((trace) async {
    //       ApiModule();
    //       ApiViaModule();
    //       PersistenceModule();
    //       GeneratorModule();
    //       DeviceModule();
    //       injector.register<Act>(mockedAct);
    //
    //       final id = MockAccountId();
    //       when(id.get()).thenReturn("test");
    //       injector.register<AccountId>(id);
    //
    //       final ops = MockHttpOps();
    //       injector.register<HttpOps>(ops);
    //       when(ops.doGet(any)).thenAnswer((_) async => "dupa");
    //       injector.inject();
    //
    //       final Device device = injector.get();
    //       await device.reload();
    //     });
    //   });
  });

  group("inheritance", () {
    test("basic", () async {
      await withTrace((trace) async {
        final subject = _TwoTest();
        expect(await subject.a(), "b1");
      });
    });
  });
}

class _OneTest with _Test {
  @override
  Future<String> a() async => b();
  @override
  Future<String> b() async => "b1";
}

class _TwoTest extends _OneTest {
  @override
  Future<String> a() async {
    print("two a");
    return super.a();
  }

  @override
  Future<String> b() async {
    print("two b");
    return super.b();
  }
}

mixin _Test {
  Future<String> a() async => "a";
  Future<String> b() async => "b";
}
