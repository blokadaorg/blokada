import 'dart:io' as io;

import 'package:common/common/widget/support/support_dialog.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/widget/profile/profile_dialog.dart';
import 'package:common/plus/widget/pause_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showSupportDialog(BuildContext context) {
  showDefaultDialog(context,
      title: Text("universal action more".i18n),
      content: (context) => const SupportDialog(),
      actions: (context) => []);
}

void showSelectProfileDialog(BuildContext context,
    {required JsonDevice device, Function(JsonProfile)? onSelected}) {
  showDefaultDialog(
    context,
    title: Text("family profile action select".i18n),
    content: (context) => ProfileDialog(
        deviceTag: device.deviceTag,
        onSelected: onSelected != null
            ? (profile) {
                Navigator.of(context).pop();
                onSelected.call(profile);
              }
            : null),
    actions: (context) => [],
  );
}

void showPauseDialog(BuildContext context,
    {required Function(Duration?) onSelected}) {
  showDefaultDialog(
    context,
    title: Text("home power off menu header".i18n),
    content: (context) => PauseDialog(
      onSelected: onSelected,
    ),
    actions: (context) => [],
  );
}

void showConfirmDialog(BuildContext context, String name,
    {required Function() onConfirm}) {
  showDefaultDialog(
    context,
    title: Text("family device action delete".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("family device delete confirm".i18n.withParams(name)),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
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
          onConfirm();
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: Text("universal action delete".i18n,
            style: const TextStyle(color: Colors.red)),
      ),
    ],
  );
}

void showRenameDialog(BuildContext context, String what, String? name,
    {required Function(String) onConfirm}) {
  final TextEditingController ctrl = TextEditingController(text: name);

  showDefaultDialog(
    context,
    title: Text(_getTitle(what, name)),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_getBrief(what)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Material(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.bgColor,
                focusColor: context.theme.bgColor,
                hoverColor: context.theme.bgColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
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
          onConfirm(ctrl.text);
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: Text("universal action save".i18n),
      ),
    ],
  );
}

String _getTitle(String what, String? name) {
  if (what == "device") {
    if (name == null) {
      return "family dialog title new device".i18n;
    } else {
      return "family dialog title rename device".i18n;
    }
  } else {
    if (name == null) {
      return "family dialog title new profile".i18n;
    } else {
      return "family dialog title rename profile".i18n;
    }
  }
}

String _getBrief(String what) {
  if (what == "device") {
    return "family dialog brief device".i18n;
  } else {
    return "family dialog brief profile".i18n;
  }
}

void showAddExceptionDialog(
  BuildContext context, {
  required Function(String) onConfirm,
}) {
  final TextEditingController _ctrl = TextEditingController(text: "");

  showDefaultDialog(
    context,
    title: const Text("Add exception"),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
            "Enter a hostname to add to your exceptions. You may use a star as a wildcard: *.example.com"),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Material(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.bgColor,
                focusColor: context.theme.bgColor,
                hoverColor: context.theme.bgColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(_ctrl.text);
        },
        child: Text("universal action save".i18n),
      ),
    ],
  );
}

void showInputDialog(
  BuildContext context, {
  required String title,
  required String desc,
  required String inputValue,
  required Function(String) onConfirm,
}) {
  final TextEditingController _ctrl = TextEditingController(text: inputValue);

  showDefaultDialog(
    context,
    title: Text(title),
    content: (context) => Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(desc),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Material(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.theme.bgColor,
                  focusColor: context.theme.bgColor,
                  hoverColor: context.theme.bgColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: context.theme.bgColor, width: 0.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: context.theme.bgColor, width: 0.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(_ctrl.text);
        },
        child: Text("universal action save".i18n),
      ),
    ],
  );
}

void showAccountIdDialog(BuildContext context, String accountId) {
  showDefaultDialog(
    context,
    title: Text("account label id".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(accountId),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: accountId));
          Navigator.of(context).pop();
        },
        child: Text("universal action copy".i18n),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text("universal action close".i18n),
      ),
    ],
  );
}

void showErrorDialog(BuildContext context, String? description) {
  showDefaultDialog(
    context,
    title: Text("alert error header".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(description ?? "error unknown".i18n),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text("universal action close".i18n),
      ),
    ],
  );
}

void showDefaultDialog(
  context, {
  required Text title,
  required Widget Function(BuildContext) content,
  required List<Widget> Function(BuildContext) actions,
}) {
  io.Platform.isIOS || io.Platform.isMacOS
      ? showCupertinoDialog<String>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: title,
            content: content(context),
            actions: actions(context),
          ),
        )
      : showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => AlertDialog(
            title: title,
            backgroundColor: context.theme.panelBackground,
            content: content(context),
            actions: actions(context),
          ),
        );
}
