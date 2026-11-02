import 'package:common/src/core/core.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:flutter/widgets.dart';

/// Locks the app with a PIN typed in Settings → change PIN.
///
/// A PIN that is not four digits is explained here, in Flutter, while
/// [context] is still on screen: the native platforms render no alert for a
/// bad PIN, so leaving it to [LockActor] alone looked like the tap was
/// ignored. [onAccepted] runs only for a valid PIN, right before locking, so
/// Settings closes as before and stays open to show the error otherwise.
Future<void> changePin(
  BuildContext context,
  Marker m,
  String pin, {
  required VoidCallback onAccepted,
}) async {
  if (!context.mounted) return;
  if (!isValidPin(pin)) {
    showErrorDialog(context, "error lock invalid".i18n);
    return;
  }
  onAccepted();
  await Core.get<LockActor>().lock(m, pin);
}
