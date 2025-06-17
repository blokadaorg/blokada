import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';

void showPauseActionSheet(BuildContext context,
    {required Function(Duration?) onSelected}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext context) => CupertinoActionSheet(
      title: Text("home status active".i18n),
      message: Text("home power off menu header".i18n),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            onSelected(const Duration(minutes: 5));
            Navigator.pop(context);
          },
          child: Text("home power action pause".i18n,
              style: TextStyle(color: context.theme.cloud)),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            onSelected(null);
            Navigator.pop(context);
          },
          child: Text("home power action turn off".i18n),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("universal action cancel".i18n,
              style: TextStyle(color: context.theme.cloud)),
        ),
      ],
    ),
  );
}
