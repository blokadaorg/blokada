import 'package:common/common/i18n.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/device/open_perms.dart';
import 'package:common/dragon/widget/home/private_dns_setting_guide.dart';
import 'package:common/util/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivateDnsSheetIos extends StatefulWidget {
  const PrivateDnsSheetIos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetIosState();
}

class PrivateDnsSheetIosState extends State<PrivateDnsSheetIos> {
  late final _openPerms = dep<OpenPerms>();

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
                          "family perms brief alt"
                              .i18n
                              .withParams("Blokada Family"),
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
                            const PrivateDnsSettingGuideWidget(
                              title: "Blokada Family",
                              subtitle: "Blokada Family",
                              iconReplacement: Image(
                                image: AssetImage('assets/images/appicon.png'),
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
                        onTap: () {
                          Navigator.of(context).pop();
                          _openPerms.open();
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
