import 'package:common/src/core/core.dart';
import 'package:common/src/features/settings/ui/settings_section.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/material.dart';

/// Settings hub. On expanded windows the section list is the master pane
/// and the selected sub-page (initially Exceptions) renders alongside it;
/// trailing top-bar actions come from DetailRoutes per shown sub-page, so
/// the Add-exception action appears whenever Exceptions is visible (the
/// old hand-rolled pane only showed an action for Support). Support is
/// deliberately not a pane path — it never worked in the pane and now
/// always pushes full-screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WithDetailPane(
      title: (Core.act.isFamily) ? "account action my account".i18n : "main tab settings".i18n,
      screenSemanticsId: AutomationIds.screenSettings,
      master: const SettingsSection(isHeader: false),
      detailPaths: const {
        Paths.settingsExceptions,
        Paths.settingsRetention,
        Paths.settingsVpnDevices,
        Paths.settingsVpnBypass,
      },
      initialDetail: Paths.settingsExceptions,
    );
  }
}
