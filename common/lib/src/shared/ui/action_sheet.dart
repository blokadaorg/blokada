import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';

void showPauseActionSheet(BuildContext context,
    {required Function(Duration?) onSelected}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext context) => Semantics(
      identifier: AutomationIds.powerActionSheet,
      container: true,
      child: CupertinoActionSheet(
        title: Text("home power pause status active".i18n),
        message: Text("home power off menu header".i18n),
        // The identifier must wrap the whole tappable action (merged into one
        // node) to surface as an iOS accessibilityIdentifier; on the inner
        // Text child alone it stays on a non-hittable node and Appium cannot
        // resolve it (same root cause fixed for SettingsItem/filter_option).
        // Semantics/MergeSemantics are zero-layout so the sheet is unchanged.
        actions: <Widget>[
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionPauseFive,
              button: true,
              child: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () {
                  onSelected(const Duration(minutes: 5));
                  Navigator.pop(context);
                },
                child: Text("home power action pause five".i18n,
                    style: TextStyle(color: context.theme.cloud)),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionTurnOff,
              button: true,
              child: CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  onSelected(null);
                  Navigator.pop(context);
                },
                child: Text("home power action off all".i18n),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionCancel,
              button: true,
              child: CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("universal action cancel".i18n,
                    style: TextStyle(color: context.theme.cloud)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
