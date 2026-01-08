import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

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
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              onSelected(const Duration(minutes: 5));
              Navigator.pop(context);
            },
            child: Semantics(
              identifier: AutomationIds.powerActionPauseFive,
              button: true,
              child: Text("home power action pause five".i18n,
                  style: TextStyle(color: context.theme.cloud)),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              onSelected(null);
              Navigator.pop(context);
            },
            child: Semantics(
              identifier: AutomationIds.powerActionTurnOff,
              button: true,
              child: Text("home power action off all".i18n),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Semantics(
              identifier: AutomationIds.powerActionCancel,
              button: true,
              child: Text("universal action cancel".i18n,
                  style: TextStyle(color: context.theme.cloud)),
            ),
          ),
        ],
      ),
    ),
  );
}
