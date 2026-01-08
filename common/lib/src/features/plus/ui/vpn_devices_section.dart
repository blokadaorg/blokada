import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/plus/ui/vpn_devices_list.dart';
import 'package:flutter/material.dart';

class VpnDevicesSection extends StatefulWidget {
  final bool primary;

  const VpnDevicesSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => VpnDevicesSectionState();
}

class VpnDevicesSectionState extends State<VpnDevicesSection> with Logging {
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          primary: widget.primary,
          children: [
            SizedBox(height: getTopPadding(context)),
            CommonCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Text("account lease label devices list".i18n,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: context.theme.textSecondary))),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 24.0, bottom: 12),
              child: Text("account lease label devices".i18n,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const VpnDevicesList(),
          ],
        ));
  }
}
