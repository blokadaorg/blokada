import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/plus/domain/vpn/vpn.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

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
  });
}
