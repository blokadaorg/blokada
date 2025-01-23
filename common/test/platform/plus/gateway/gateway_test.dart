import 'package:common/core/core.dart';
import 'package:common/platform/plus/gateway/api.dart';
import 'package:common/platform/plus/gateway/channel.pg.dart';
import 'package:common/platform/plus/gateway/gateway.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusGatewayStore>(),
  MockSpec<PlusGatewayOps>(),
  MockSpec<PlusGatewayApi>(),
  MockSpec<Persistence>(),
  MockSpec<StageStore>(),
])
import 'gateway_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockPlusGatewayOps();
        Core.register<PlusGatewayOps>(ops);

        final json = MockPlusGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<PlusGatewayApi>(json);

        final subject = PlusGatewayStore();
        expect(subject.gateways.isEmpty, true);
        expect(subject.gatewayChanges, 0);

        await subject.fetch(m);
        expect(subject.gateways.length, 3);
        expect(subject.gateways.first.country, 'US');
        expect(subject.gatewayChanges, 1);
      });
    });

    test("load", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockPlusGatewayOps();
        Core.register<PlusGatewayOps>(ops);

        final persistence = MockPersistence();
        when(persistence.load(any, any)).thenAnswer((_) =>
            Future.value("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4="));
        Core.register<Persistence>(persistence);

        final json = MockPlusGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<PlusGatewayApi>(json);

        final subject = PlusGatewayStore();
        await subject.fetch(m);
        expect(subject.currentGateway, null);

        await subject.load(m);
        expect(subject.currentGateway, isNotNull);
        expect(subject.currentGateway!.publicKey,
            "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=");
      });
    });

    test("selectGateway", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockPlusGatewayOps();
        Core.register<PlusGatewayOps>(ops);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final json = MockPlusGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<PlusGatewayApi>(json);

        final subject = PlusGatewayStore();
        await subject.fetch(m);
        expect(subject.currentGateway, null);

        // Basic select gateway
        await subject.selectGateway(
            "H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=", m);
        expect(subject.currentGateway, isNotNull);
        expect(subject.currentGateway!.country, "DE");
        verify(persistence.save(any, any, any)).called(1);

        // Throw on select non-existing gateway, old selection still set
        await expectLater(
            subject.selectGateway("not-existing-gateway", m), throwsException);
        expect(subject.currentGateway, isNotNull);

        // Unselect gateway
        await subject.selectGateway(null, m);
        expect(subject.currentGateway, null);
        verify(persistence.delete(any, any)).called(1);
      });
    });
  });
}
