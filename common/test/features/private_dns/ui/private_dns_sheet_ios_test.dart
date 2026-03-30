import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_ios.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';

class _MockDeviceStore extends Mock implements DeviceStore {}

class _MockPermChannel extends Mock implements PermChannel {}

void main() {
  testWidgets('dismisses the DNS sheet when foreground verification resolves', (tester) async {
    await withTrace((m) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 2000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final device = _MockDeviceStore();
      when(device.deviceTag).thenReturn('225024');
      Core.register<DeviceStore>(device);

      Core.register<PermChannel>(_MockPermChannel());

      final dnsEnabledFor = PrivateDnsEnabledForValue();
      Core.register(dnsEnabledFor);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              BlokadaTheme(
                bgColor: Colors.black,
                bgColorHome1: Colors.black,
                bgColorHome2: Colors.black,
                bgColorHome3: Colors.black,
                bgColorCard: Colors.black,
                panelBackground: Colors.black,
                cloud: Colors.blue,
                accent: Colors.blue,
                freemium: Colors.orange,
                shadow: Colors.black,
                bgMiniCard: Colors.black,
                textPrimary: Colors.white,
                textSecondary: Colors.white70,
                divider: Colors.grey,
              ),
            ],
          ),
          home: Navigator(
            onGenerateInitialRoutes: (_, __) => [
              MaterialPageRoute<void>(
                builder: (_) => const SizedBox(key: Key('home')),
              ),
              MaterialPageRoute<void>(
                builder: (_) => const PrivateDnsSheetIos(),
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(PrivateDnsSheetIos), findsOneWidget);

      await dnsEnabledFor.change(m, '225024');
      await tester.pumpAndSettle();

      expect(find.byType(PrivateDnsSheetIos), findsNothing);
      expect(find.byKey(const Key('home')), findsOneWidget);
    });
  });
}
