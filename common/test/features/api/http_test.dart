import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/plus/domain/vpn/vpn.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([MockSpec<AppStore>(), MockSpec<StageStore>(), MockSpec<DeviceStore>()])
import 'http_test.mocks.dart';

void main() {
  group("http", () {
    test("vpnStatusForDiagReadsRegisteredStatus", () async {
      await withTrace((m) async {
        final status = CurrentVpnStatusValue();
        Core.register(status);
        status.now = VpnStatus.activated;

        expect(Http().vpnStatusForDiag(), VpnStatus.activated.name);
      });
    });

    test("vpnStatusForDiagWithoutVpnModule", () async {
      await withTrace((m) async {
        expect(Http().vpnStatusForDiag(), "(unavailable)");
      });
    });

    test("netDiagLogCarriesVpnStatus", () async {
      await withTrace((m) async {
        final tracer = _CapturingTracer();
        Core.di.allowReassignment = true;
        try {
          Core.register<LogTracerActor>(tracer);
        } finally {
          Core.di.allowReassignment = false;
        }

        final status = CurrentVpnStatusValue();
        Core.register(status);
        status.now = VpnStatus.activated;

        Core.register<HttpChannel>(_OkHttp());
        Core.register(BaseUrl());
        Core.register(UserAgent());
        Core.register(AccountId());
        Core.register(ApiRetryDuration());
        Core.register<AppStore>(MockAppStore());
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<DeviceStore>(MockDeviceStore());
        Core.register(PrivateDnsEnabledForValue());
        await Core.get<UserAgent>().change(m, "test-agent");

        await Http().call(HttpRequest(ApiEndpoint.getGateways), m, skipResolvingParams: true);

        final vpnLines = tracer.lines.where((l) => l.contains("🔍 vpnStatus = ")).toList();
        expect(vpnLines, isNotEmpty);
        expect(vpnLines, everyElement(endsWith("vpnStatus = activated")));
      });
    });
  });
}

class _CapturingTracer extends LogTracerActor {
  final lines = <String>[];

  @override
  sink(Marker m, Level lvl, List<String> lines, {Object? err, StackTrace? stack}) {
    this.lines.addAll(lines);
    super.sink(m, lvl, lines, err: err, stack: stack);
  }
}

class _OkHttp with HttpChannel {
  @override
  Future<String> doGet(String url) async => "{}";

  @override
  Future<String> doRequest(String url, String? payload, String type) async => "{}";

  @override
  Future<String> doRequestWithHeaders(
    String url,
    String? payload,
    String type,
    Map<String?, String?> h,
  ) async => "{}";
}
