import 'dart:io' as io;

import 'package:common/common/model.dart';
import 'package:common/common/widget/string.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/widget/profile/profile_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showSelectProfileDialog(BuildContext context,
    {required JsonDevice device, Function(JsonProfile)? onSelected}) {
  showDefaultDialog(
    context,
    title: const Text("Select profile"),
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

void showConfirmDialog(BuildContext context, String name,
    {required Function() onConfirm}) {
  showDefaultDialog(
    context,
    title: const Text("Delete device"),
    content: (context) => Column(
      children: [
        Text(
            "Are you sure you wish to delete $name? The device will be unlinked from your account."),
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
        child: const Text("Cancel"),
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
        child: const Text("Delete", style: TextStyle(color: Colors.red)),
      ),
    ],
  );
}

void showRenameDialog(BuildContext context, String what, String? name,
    {required Function(String) onConfirm}) {
  final TextEditingController _ctrl = TextEditingController(text: name);

  showDefaultDialog(
    context,
    title: Text(name == null
        ? "New ${what.firstLetterUppercase()}"
        : "Rename ${what.firstLetterUppercase()}"),
    content: (context) => Column(
      children: [
        Text("Enter a name for this $what."),
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
        onPressed: () {
          Navigator.of(context).pop();
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: const Text("Cancel"),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(_ctrl.text);
        },
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
        child: const Text("Save"),
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
    content: (context) => Column(
      children: [
        Text(desc),
        const SizedBox(height: 16),
        Material(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.theme.panelBackground,
              focusColor: context.theme.panelBackground,
              hoverColor: context.theme.panelBackground,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: context.theme.divider, width: 1.0),
                borderRadius: BorderRadius.circular(2.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: context.theme.divider, width: 1.0),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Cancel"),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(_ctrl.text);
        },
        child: const Text("Save"),
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
            content: content(context),
            actions: actions(context),
          ),
        );
}
