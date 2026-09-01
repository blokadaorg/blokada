import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:flutter/material.dart';

/// Confirmation shown before an incoming link re-homes an already set up
/// device. The confirm action is red, matching the delete confirms. The dialog
/// is barrier dismissible, so an unanswered close counts as a cancel.
Future<void> showLinkConfirmDialog(
  BuildContext context, {
  required Function() onConfirm,
  required Function() onCancel,
}) async {
  var answered = false;

  await showDefaultDialog(
    context,
    title: Text("family link confirm header".i18n),
    content: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("family link confirm body".i18n),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          answered = true;
          Navigator.of(context).pop();
          onCancel();
        },
        child: Text("universal action cancel".i18n),
      ),
      TextButton(
        onPressed: () {
          answered = true;
          Navigator.of(context).pop();
          onConfirm();
        },
        child: Text("family link confirm action".i18n,
            style: const TextStyle(color: Colors.red)),
      ),
    ],
  );

  if (!answered) onCancel();
}
