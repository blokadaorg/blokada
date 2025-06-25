import 'package:common/common/module/safari/safari.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/safari/safari_setting_guide.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SafariContentOnboardSheetIos extends StatefulWidget {
  const SafariContentOnboardSheetIos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SafariContentOnboardSheetIosState();
}

class SafariContentOnboardSheetIosState extends State<SafariContentOnboardSheetIos> {
  final _onboard = Core.get<SafariContentActor>();

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
                        "Block ads in Safari",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "Enable our extension in Safari to block ads and trackers on websites you visit.",
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
                              style: TextStyle(color: context.theme.textSecondary),
                            ),
                            SafariSettingGuideWidget(
                              title: "onboard safari step 2".i18n,
                              widgetRight: Icon(
                                size: 16,
                                Icons.extension_outlined,
                                color: context.theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "2.",
                              style: TextStyle(color: context.theme.textSecondary),
                            ),
                            SafariSettingGuideWidget(
                              title: "Blokada",
                              iconReplacement: Image(
                                image: AssetImage('assets/images/v6-appicon.png'),
                                width: 24,
                              ),
                              widgetRight: Transform.scale(
                                scale: 0.8,
                                child: Transform.translate(
                                  offset: const Offset(12, 0),
                                  child: CupertinoSwitch(value: true, onChanged: (_) => {}),
                                ),
                              ),
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
                          _onboard.doOpenPermsFlow(Markers.userTap);
                        },
                        color: context.theme.accent,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "Open Safari",
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: MiniCard(
                        onTap: () async {
                          Navigator.of(context).pop();
                          //_onboard.markSafariYoutubeSeen(Markers.userTap);
                        },
                        color: context.theme.bgColor,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "onboard safari skip".i18n,
                              style: TextStyle(
                                color: context.theme.textPrimary,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
