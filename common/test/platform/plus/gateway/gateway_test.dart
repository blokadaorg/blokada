import 'package:common/core/core.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<GatewayActor>(),
  MockSpec<GatewayChannel>(),
  MockSpec<GatewayApi>(),
  MockSpec<Persistence>(),
  MockSpec<StageStore>(),
])
import 'gateway_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockGatewayChannel();
        Core.register<GatewayChannel>(ops);

        final json = MockGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<GatewayApi>(json);

        final subject = GatewayActor();
        expect(subject.gateways.isEmpty, true);

        await subject.fetch(m);
        expect(subject.gateways.length, 3);
        expect(subject.gateways.first.country, 'US');
      });
    });

    test("load", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockGatewayChannel();
        Core.register<GatewayChannel>(ops);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final currentGateway = CurrentGatewayValue();
        Core.register(currentGateway);

        final currentGatewayId = CurrentGatewayIdValue();
        await currentGatewayId.change(
            m, "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=");
        Core.register(currentGatewayId);

        final json = MockGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<GatewayApi>(json);

        final subject = GatewayActor();
        await subject.fetch(m);
        expect(currentGateway.present, null);

        await subject.load(m);
        expect(currentGateway.present, isNotNull);
        expect(currentGateway.present!.publicKey,
            "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=");
      });
    });

    test("selectGateway", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockGatewayChannel();
        Core.register<GatewayChannel>(ops);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final currentGateway = CurrentGatewayValue();
        Core.register(currentGateway);

        Core.register(CurrentGatewayIdValue());

        final json = MockGatewayApi();
        when(json.get(any))
            .thenAnswer((_) => Future.value(fixtureGatewayEntries));
        Core.register<GatewayApi>(json);

        final subject = GatewayActor();
        await subject.fetch(m);
        expect(currentGateway.present, null);

        // Basic select gateway
        await subject.selectGateway(
            "H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=", m);
        expect(currentGateway.present, isNotNull);
        expect(currentGateway.present!.country, "DE");
        verify(persistence.save(any, any, any)).called(1);

        // Throw on select non-existing gateway, old selection still set
        await expectLater(
            subject.selectGateway("not-existing-gateway", m), throwsException);
        expect(currentGateway.present, isNotNull);

        // Unselect gateway
        await subject.selectGateway(null, m);
        expect(currentGateway.present, null);
        verify(persistence.delete(any, any)).called(1);
      });
    });
  });
}
