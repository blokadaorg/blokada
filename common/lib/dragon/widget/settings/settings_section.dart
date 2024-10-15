import 'package:common/account/account.dart';
import 'package:common/command/command.dart';
import 'package:common/common/i18n.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/string.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/home/bg.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/section_label.dart';
import 'package:common/dragon/widget/settings/settings_item.dart';
import 'package:common/env/env.dart';
import 'package:common/link/channel.pg.dart';
import 'package:common/logger/logger.dart';
import 'package:common/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../lock/lock.dart';
import '../../../util/di.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<StatefulWidget> createState() => SettingsState();
}

class SettingsState extends State<SettingsSection> with Logging {
  late final _lock = dep<LockStore>();
  late final _stage = dep<StageStore>();
  late final _env = dep<EnvStore>();
  late final _account = dep<AccountStore>();
  late final _command = dep<CommandStore>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        primary: true,
        children: [
          SizedBox(height: getTopPadding(context)),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  const FamilyBgWidget(),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.asset(
                            "assets/images/family-logo.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(_getAccountSubText(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          SectionLabel(
              text: "account section header primary".i18n.capitalize()),
          CommonCard(
            child: Column(
              children: [
                // SettingsItem(
                //     icon: CupertinoIcons.shield_lefthalf_fill,
                //     text: "My exceptions",
                //     onTap: () {
                //       Navigation.open(context, Paths.settingsExceptions);
                //     }),
                // const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.ellipsis,
                    text: "family settings lock pin".i18n,
                    onTap: () {
                      if (_lock.hasPin) {
                        _showPinDialog(
                          context,
                          title: "family settings lock pin".i18n,
                          desc: "family settings lock enter".i18n,
                          inputValue: "",
                          onConfirm: (String value) {
                            log(Markers.userTap).trace("tappedChangePin",
                                (m) async {
                              Navigator.of(context).pop();
                              await _lock.lock(value, m);
                            });
                          },
                          onRemove: () {
                            log(Markers.userTap).trace("tappedRemovePin",
                                (m) async {
                              await _lock.removeLock(m);
                            });
                          },
                        );
                      } else {
                        log(Markers.userTap).trace("tappedLock", (m) async {
                          await _lock.autoLock(m);
                        });
                      }
                    }),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SectionLabel(text: "universal action help".i18n.capitalize()),
          CommonCard(
            child: Column(
              children: [
                SettingsItem(
                    icon: CupertinoIcons.chat_bubble_text,
                    text: "Chat with us",
                    onTap: () => Navigation.open(context, Paths.support)),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.person_3,
                    text: "universal action community".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("settingsOpenCommunity",
                          (m) async {
                        await _stage.openLink(LinkId.knowledgeBase, m);
                      });
                    }),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SectionLabel(text: "account section header other".i18n.capitalize()),
          CommonCard(
            child: Column(
              children: [
                SettingsItem(
                    icon: CupertinoIcons.return_icon,
                    text: "account action logout new".i18n,
                    onTap: () => _showRestoreDialog(context)),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.doc_text,
                    text: "universal action share log".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("supportSendLog", (m) async {
                        await _command.onCommand("log", m);
                      });
                    }),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.person_2,
                    text: "account action about".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("settingsOpenAbout",
                          (m) async {
                        await _stage.openLink(LinkId.credits, m);
                      });
                    }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
              child: Text(_getAppVersion(),
                  style: TextStyle(color: context.theme.divider))),
        ],
      ),
    );
  }

  _showRestoreDialog(BuildContext context) {
    showInputDialog(context,
        title: "account action logout new".i18n,
        desc: "family account restore desc".i18n,
        inputValue: "", onConfirm: (String value) {
      log(Markers.userTap).trace("tappedRestore", (m) async {
        await _account.restore(value, m);
      });
    });
  }

  String _getAccountSubText() {
    final expire = _account.account?.jsonAccount.activeUntil;
    if (expire == null) {
      return "account status text inactive".i18n;
    }

    final date = DateTime.tryParse(expire);
    if (date == null) {
      return "account status text inactive".i18n;
    }

    if (date.isBefore(DateTime.now())) {
      return "account status text inactive".i18n;
    }

    String formattedDate =
        "${date.year}-${padZero(date.month)}-${padZero(date.day)}";

    return "account status text"
        .i18n
        .withParams(_account.type.name.firstLetterUppercase(), formattedDate);
  }

  String _getAppVersion() {
    return "Version ${_env.appVersion ?? "unknown"}";
  }

  String padZero(int number) {
    return number.toString().padLeft(2, '0');
  }
}

void _showPinDialog(
  BuildContext context, {
  required String title,
  required String desc,
  required String inputValue,
  required Function(String) onConfirm,
  required Function() onRemove,
}) {
  final pinTheme = PinTheme(
    width: 56,
    height: 56,
    textStyle: TextStyle(
        fontSize: 22, color: context.theme.accent, fontWeight: FontWeight.w500),
    decoration: BoxDecoration(
      border: Border.all(color: context.theme.divider),
      borderRadius: BorderRadius.circular(16),
    ),
  );

  showDefaultDialog(
    context,
    title: Text(title),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(desc),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: Pinput(
            defaultPinTheme: pinTheme,
            onCompleted: (pin) {
              Navigator.of(context).pop();
              onConfirm(pin);
            },
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onRemove();
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: Text(
          "family settings lock remove".i18n,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ],
  );
}
