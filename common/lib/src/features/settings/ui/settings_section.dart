import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/rate/domain/rate.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/section_label.dart';
import 'package:common/src/features/settings/ui/settings_item.dart';
import 'package:common/src/shared/ui/string.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/home/bg.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:input_code_field/input_code_field.dart';

import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/notification/domain/notification.dart';

class SettingsSection extends StatefulWidget {
  final bool isHeader;

  const SettingsSection({super.key, required this.isHeader});

  @override
  State<StatefulWidget> createState() => SettingsState();
}

class SettingsState extends State<SettingsSection> with Logging, Disposables {
  late final _stage = Core.get<StageStore>();
  late final _env = Core.get<EnvActor>();
  late final _account = Core.get<AccountStore>();
  late final _perm = Core.get<PlatformPermActor>();
  late final _command = Core.get<CommandStore>();
  late final _unread = Core.get<SupportUnread>();
  late final _rate = Core.get<RateActor>();
  late final _notification = Core.get<NotificationActor>();

  late final _lock = Core.get<LockActor>();
  late final _hasPin = Core.get<HasPin>();
  late final _weeklyOptOut = Core.get<WeeklyReportOptOutValue>();

  bool _weeklyReportEnabled = true;

  @override
  void initState() {
    super.initState();
    disposeLater(_unread.onChange.listen(rebuild));
    disposeLater(_hasPin.onChange.listen(rebuild));
    disposeLater(_weeklyOptOut.onChange.listen((update) {
      setState(() {
        _weeklyReportEnabled = !update.now;
      });
    }));
    _unread.fetch(Markers.ui);
    _weeklyOptOut.fetch(Markers.ui).then((value) {
      setState(() {
        _weeklyReportEnabled = !value;
      });
    });
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        primary: true,
        children: [
          // Header for v6 or padding for Family
          (widget.isHeader)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "main tab settings".i18n,
                      style: const TextStyle(
                        fontSize: 34.0, // Mimic large iOS-style header
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                )
              : SizedBox(height: getTopPadding(context)),
          // The rest of the screen
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  Container(
                    color: context.theme.bgColorCard,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Core.act.isFamily ? const FamilyBgWidget() : Container(),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.asset(
                            Core.act.isFamily
                                ? "assets/images/family-logo.png"
                                : "assets/images/blokada_logo.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(_getAccountSubText(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color:
                                    Core.act.isFamily ? Colors.white : context.theme.textPrimary)),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
          (_account.isFreemium)
              ? Container()
              : Column(
                  children: [
                    const SizedBox(height: 48),
                    SectionLabel(text: "account section header primary".i18n.capitalize()),
                    CommonCard(
                      child: Column(
                        children: [
                          (!Core.act.isFamily)
                              ? Column(
                                  children: [
                                    SettingsItem(
                                        icon: CupertinoIcons.shield_lefthalf_fill,
                                        text: "family stats title".i18n, // My exceptions
                                        onTap: () {
                                          Navigation.open(Paths.settingsExceptions);
                                        }),
                                    const CommonDivider(),
                                    SettingsItem(
                                        icon: CupertinoIcons.chart_bar,
                                        text: "activity section header".i18n,
                                        onTap: () {
                                          Navigation.open(Paths.settingsRetention);
                                        }),
                                    const CommonDivider(),
                                    (_account.type == AccountType.plus)
                                        ? Column(
                                            children: [
                                              SettingsItem(
                                                  icon: CupertinoIcons.device_desktop,
                                                  text: "web vpn devices header".i18n,
                                                  onTap: () {
                                                    Navigation.open(Paths.settingsVpnDevices);
                                                  }),
                                              const CommonDivider(),
                                            ],
                                          )
                                        : Container(),
                                    (_account.type == AccountType.plus && Core.act.isAndroid)
                                        ? Column(
                                            children: [
                                              SettingsItem(
                                                  icon: Icons.web_stories_outlined,
                                                  text: "bypass section header".i18n,
                                                  onTap: () {
                                                    Navigation.open(Paths.settingsVpnBypass);
                                                  }),
                                              const CommonDivider(),
                                            ],
                                          )
                                        : Container(),
                                  ],
                                )
                              : Container(),
                          SettingsItem(
                              icon: CupertinoIcons.ellipsis,
                              text: "family settings lock pin".i18n,
                              onTap: () {
                                if (_hasPin.now) {
                                  _showPinDialog(
                                    context,
                                    title: "family settings lock pin".i18n,
                                    desc: "family settings lock enter".i18n,
                                    inputValue: "",
                                    onConfirm: (String value) {
                                      log(Markers.userTap).trace("tappedChangePin", (m) async {
                                        Navigator.of(context).pop();
                                        await _lock.lock(m, value);
                                      });
                                    },
                                    onRemove: () {
                                      log(Markers.userTap).trace("tappedRemovePin", (m) async {
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
                  ],
                ),
          const SizedBox(height: 32),
          SectionLabel(text: "Notifications"),
          CommonCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Weekly privacy report",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Send a weekly summary of tracker activity",
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  activeColor: context.theme.accent,
                  value: _weeklyReportEnabled,
                  onChanged: (bool value) async {
                    final previous = _weeklyReportEnabled;
                    setState(() {
                      _weeklyReportEnabled = value;
                    });
                    try {
                      await _notification.setWeeklyReportEnabled(Markers.userTap, value);
                    } catch (_) {
                      if (!mounted) return;
                      setState(() {
                        _weeklyReportEnabled = previous;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SectionLabel(text: "account section header my subscription".i18n.capitalize()),
          CommonCard(
            child: Column(
              children: [
                (!Core.act.isFamily || !Core.act.isRelease)
                    ? Column(
                        children: [
                          SettingsItem(
                              icon: CupertinoIcons.person_crop_circle,
                              text: "account action my account".i18n,
                              onTap: () {
                                _perm.authenticate(Markers.userTap, () {
                                  showAccountIdDialog(context, _account.id);
                                });
                              }),
                          const CommonDivider(),
                        ],
                      )
                    : Container(),
                SettingsItem(
                    icon: CupertinoIcons.return_icon,
                    text: "account action logout new".i18n,
                    onTap: () => _showRestoreDialog(context)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SectionLabel(text: "universal action help".i18n.capitalize()),
          CommonCard(
            child: Column(
              children: [
                SettingsItem(
                    unread: _unread.present ?? false,
                    icon: CupertinoIcons.chat_bubble_text,
                    text: "support action chat".i18n,
                    onTap: () => Navigation.open(Paths.support)),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.person_3,
                    text: "universal action community".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("settingsOpenCommunity", (m) async {
                        await _stage.openLink(LinkId.knowledgeBase, m);
                      });
                    }),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.doc_text,
                    text: "universal action share log".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("supportSendLog", (m) async {
                        await _command.onCommand(CommandName.shareLog.name, m);
                      });
                    }),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.person_2,
                    text: "account action about".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("settingsOpenAbout", (m) async {
                        await _stage.openLink(LinkId.credits, m);
                      });
                    }),
                const CommonDivider(),
                SettingsItem(
                    icon: CupertinoIcons.star_fill,
                    text: "main rate us header".i18n,
                    onTap: () {
                      log(Markers.userTap).trace("settingsOpenRate", (m) async {
                        await _rate.show(m);
                      });
                    }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(_getAppVersion(), style: TextStyle(color: context.theme.divider))),
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

    String formattedDate = "${date.year}-${padZero(date.month)}-${padZero(date.day)}";

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
  late final InputCodeControl ctrl = InputCodeControl(inputRegex: '^[0-9]*\$');

  showDefaultDialog(
    context,
    title: Text(title),
    content: (context) {
      ctrl.done(() {
        Navigator.of(context).pop();
        onConfirm(ctrl.value);
      });

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(desc),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InputCodeField(
              control: ctrl,
              count: 4,
              inputType: TextInputType.number,
              decoration: InputCodeDecoration(
                  focusColor: context.theme.accent,
                  box: BoxDecoration(
                    border: Border.all(color: context.theme.divider),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBox: BoxDecoration(
                    border: Border.all(color: context.theme.accent),
                    borderRadius: BorderRadius.circular(16),
                  )),
            ),
          ),
        ],
      );
    },
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
