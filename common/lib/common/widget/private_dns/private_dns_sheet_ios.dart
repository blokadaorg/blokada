import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/private_dns/private_dns_setting_guide.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivateDnsSheetIos extends StatefulWidget {
  const PrivateDnsSheetIos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetIosState();
}

class PrivateDnsSheetIosState extends State<PrivateDnsSheetIos> {
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
                          "family perms brief alt".i18n.withParams(_appName),
                          softWrap: true,
                          textAlign: TextAlign.center,
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
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting ios general".i18n,
                              icon: CupertinoIcons.settings,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "2.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting ios vpn".i18n,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "3.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting ios dns".i18n,
                              icon: CupertinoIcons.ellipsis,
                              edgeText:
                                  "family perms setting ios automatic".i18n,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "4.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: _appName,
                              subtitle: _appName,
                              iconReplacement: Image(
                                image: AssetImage(Core.act.isFamily
                                    ? 'assets/images/family-appicon.png'
                                    : 'assets/images/v6-appicon.png'),
                                width: 24,
                              ),
                              chevron: false,
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
