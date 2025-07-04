import 'package:common/common/module/safari/safari.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/safari/safari_setting_guide.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SafariOnboardSheetIos extends StatefulWidget {
  const SafariOnboardSheetIos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SafariOnboardSheetIosState();
}

class SafariOnboardSheetIosState extends State<SafariOnboardSheetIos> {
  final _onboard = Core.get<SafariActor>();

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
                        "freemium sheet safari header".i18n,
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
                          "freemium sheet safari desc".i18n,
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
                            SafariSettingGuideWidget(
                              title: "youtube.com",
                              icon: CupertinoIcons.textformat,
                              centerTitle: true,
                              widgetRight: Icon(
                                size: 16,
                                Icons.refresh,
                                color: context.theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "2.",
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
                              "3.",
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
                          _onboard.openSafariSetup();
                        },
                        color: context.theme.accent,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "freemium sheet safari cta".i18n,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
