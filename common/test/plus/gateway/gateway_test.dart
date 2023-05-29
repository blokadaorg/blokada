import 'package:common/persistence/persistence.dart';
import 'package:common/plus/gateway/channel.pg.dart';
import 'package:common/plus/gateway/gateway.dart';
import 'package:common/plus/gateway/json.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusGatewayStore>(),
  MockSpec<PlusGatewayOps>(),
  MockSpec<PlusGatewayJson>(),
  MockSpec<PersistenceService>(),
  MockSpec<StageStore>(),
])
import 'gateway_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((trace) async {
        final ops = MockPlusGatewayOps();
        depend<PlusGatewayOps>(ops);

        final json = MockPlusGatewayJson();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        di.registerSingleton<PlusGatewayJson>(json);

        final subject = PlusGatewayStore();
        expect(subject.gateways.isEmpty, true);
        expect(subject.gatewayChanges, 0);

        await subject.fetch(trace);
        expect(subject.gateways.length, 3);
        expect(subject.gateways.first.country, 'US');
        expect(subject.gatewayChanges, 1);
      });
    });

    test("load", () async {
      await withTrace((trace) async {
        final ops = MockPlusGatewayOps();
        depend<PlusGatewayOps>(ops);

        final persistence = MockPersistenceService();
        when(persistence.load(any, any)).thenAnswer((_) =>
            Future.value("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4="));
        di.registerSingleton<PersistenceService>(persistence);

        final json = MockPlusGatewayJson();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        di.registerSingleton<PlusGatewayJson>(json);

        final subject = PlusGatewayStore();
        await subject.fetch(trace);
        expect(subject.currentGateway, null);

        await subject.load(trace);
        expect(subject.currentGateway, isNotNull);
        expect(subject.currentGateway!.publicKey,
            "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=");
      });
    });

    test("selectGateway", () async {
      await withTrace((trace) async {
        final ops = MockPlusGatewayOps();
        depend<PlusGatewayOps>(ops);

        final persistence = MockPersistenceService();
        di.registerSingleton<PersistenceService>(persistence);

        final json = MockPlusGatewayJson();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        di.registerSingleton<PlusGatewayJson>(json);

        final subject = PlusGatewayStore();
        await subject.fetch(trace);
        expect(subject.currentGateway, null);

        // Basic select gateway
        await subject.selectGateway(
            trace, "H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=");
        expect(subject.currentGateway, isNotNull);
        expect(subject.currentGateway!.country, "DE");
        verify(persistence.saveString(any, any, any)).called(1);

        // Throw on select non-existing gateway, old selection still set
        await expectLater(subject.selectGateway(trace, "not-existing-gateway"),
            throwsException);
        expect(subject.currentGateway, isNotNull);

        // Unselect gateway
        await subject.selectGateway(trace, null);
        expect(subject.currentGateway, null);
        verify(persistence.delete(any, any)).called(1);
      });
    });
  });
}
