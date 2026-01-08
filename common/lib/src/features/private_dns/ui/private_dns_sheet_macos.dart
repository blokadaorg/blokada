import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/private_dns/ui/private_dns_setting_guide.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivateDnsSheetMacos extends StatefulWidget {
  const PrivateDnsSheetMacos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetMacosState();
}

class PrivateDnsSheetMacosState extends State<PrivateDnsSheetMacos> {
  late final _channel = Core.get<PermChannel>();
  late final _appName = Core.act.isFamily ? "Blokada Family" : "Blokada 6";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        "family perms header".i18n,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "Install %s profile in Settings by navigating as shown below."
                              .i18n
                              .withParams(_appName),
                          softWrap: true,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: context.theme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24), // Replaces Spacer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "1.",
                              style: TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "Profile Downloaded".i18n,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "2.",
                              style: TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "Blokada Private DNS".i18n,
                              icon: CupertinoIcons.settings,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "3.",
                              style: TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "Install...".i18n,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24), // Replaces Spacer
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MiniCard(
                        onTap: () async {
                          Navigator.of(context).pop();
                          _channel.doOpenPermSettings();
                        },
                        color: context.theme.accent,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "dnsprofile action open settings".i18n,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
