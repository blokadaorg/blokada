import 'dart:io';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:flutter/services.dart';

/// A short confirmation shown at the bottom of the screen, above sheets.
class ToastMessage {
  final String text;
  final bool isError;

  // Distinguishes two toasts with the same text, so repeating an action
  // shows the toast again.
  final int id;

  ToastMessage(this.text, {this.isError = false, required this.id});
}

class ToastValue extends Value<ToastMessage?> {
  ToastValue() : super(load: () => null);
}

class ToastActor with Actor, Logging {
  late final _value = Core.get<ToastValue>();
  late final _env = Core.get<EnvActor>();

  int _nextId = 0;

  /// Confirms an action with a light haptic.
  void show(String text) {
    Haptics.light();
    _value.now = ToastMessage(text, id: _nextId++);
  }

  /// Reports a failed action. Shown instead of a confirmation, never with one.
  void showError(String text) {
    _value.now = ToastMessage(text, isError: true, id: _nextId++);
  }

  /// Copies [text] to the clipboard and confirms it.
  Future<void> copy(String text, Marker m) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e, s) {
      log(m).e(msg: "copy to clipboard failed", err: e, stack: s);
      return;
    }
    copied();
  }

  /// Confirms a copy to the clipboard. Android 13+ shows its own clipboard
  /// notice, so there only the haptic plays.
  void copied() {
    if (_systemShowsCopyNotice()) {
      Haptics.light();
      return;
    }
    show("universal status copied to clipboard".i18n);
  }

  bool _systemShowsCopyNotice() {
    if (!Platform.isAndroid) return false;
    try {
      final sdk = int.tryParse(_env.info.osVersion);
      return sdk != null && sdk >= 33;
    } catch (e) {
      // Env info not loaded yet: show our toast rather than nothing.
      log(Markers.ui).w("toast: env info unavailable for the copy notice check: $e");
      return false;
    }
  }
}

class ToastModule with Module {
  @override
  onCreateModule() async {
    await register(ToastValue());
    await register(ToastActor());
  }
}
