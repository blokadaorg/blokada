import 'package:common/src/features/safari/domain/safari.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/safari/ui/safari_setting_guide.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
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
    final showSetupLater = _onboard.shouldShowSetupLaterOnSafariOnboard();

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
              _SafariOnboardPrimaryButton(onTap: () async {
                Navigator.of(context).pop();
                _onboard.openSafariSetup();
              }),
              if (showSetupLater) ...[
                const SizedBox(height: 8),
                _SafariOnboardSecondaryButton(
                  onTap: () => _onboard.continueToPaywallFromBeforePaywallOnboard(Markers.userTap),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafariOnboardPrimaryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SafariOnboardPrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: MiniCard(
        onTap: onTap,
        color: context.theme.accent,
        child: SizedBox(
          width: double.infinity,
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
    );
  }
}

class _SafariOnboardSecondaryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SafariOnboardSecondaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: MiniCard(
        onTap: onTap,
        outlined: true,
        color: context.theme.accent,
        child: SizedBox(
          width: double.infinity,
          height: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "freemium sheet safari setup later".i18n,
                style: TextStyle(
                  color: context.theme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "freemium sheet safari setup later desc".i18n,
                style: TextStyle(
                  color: context.theme.textSecondary,
                  fontSize: 10,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
