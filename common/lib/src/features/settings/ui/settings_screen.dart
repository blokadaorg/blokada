import 'package:common/src/core/core.dart';
import 'package:common/src/features/settings/ui/settings_section.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/detail_pane_placeholder.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/cupertino.dart';

/// Settings hub. On expanded windows the section list is the master pane
/// with the selected sub-page alongside it; nothing is preselected (a
/// silently-opened Exceptions pane with no highlighted row read as
/// confusing), so the pane invites a selection instead. Trailing top-bar
/// actions come from DetailRoutes per shown sub-page. Support is
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
      splitWhenUnselected: true,
      placeholder: const DetailPanePlaceholder(
        icon: CupertinoIcons.slider_horizontal_3,
        text: "Select an item to see details",
      ),
    );
  }
}
