import 'package:common/common/widget.dart';
import 'package:common/common/widget/family/home/big_icon.dart';
import 'package:common/common/widget/family/home/private_dns_sheet.dart';
import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:vistraced/via.dart';

import '../../../../stage/channel.pg.dart';
import '../../../model.dart';
import '../../../../util/trace.dart';
import 'add_device_sheet.dart';

class ThisDeviceOnboard extends StatefulWidget {
  const ThisDeviceOnboard({super.key});

  @override
  State<StatefulWidget> createState() => ThisDeviceOnboardState();
}

class ThisDeviceOnboardState extends State<ThisDeviceOnboard>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final texts = [
      "My device",
      "Blokada can block ads, trackers and much more. You may also block access to unwanted content when sharing your device with your child.",
    ];

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Spacer(),
            Text(
              texts.first!,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (texts.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  texts[1]!,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Spacer(),
            SizedBox(
              height: 56,
              child: _buildButton(context),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: MiniCard(
        onTap: () {
          showCupertinoModalBottomSheet(
            context: context,
            duration: const Duration(milliseconds: 300),
            backgroundColor: context.theme.bgColorCard,
            builder: (context) => PrivateDnsSheet(),
          );
        },
        color: context.theme.accent,
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.power,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Center(
                child: Text(
                  "Turn on",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
