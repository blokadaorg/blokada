import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';

/// This is the newer approach to showing modals / dialogs.
/// Old stuff (from StageStore and Navigation) should be merged and removed.

enum Modal {
  onboardPrivateDns,
  onboardSafari,
  onboardSafariYoutube,
  plusDeviceLimitReached,
  familyAddProfile,
  familyLinkDevice,
  familyQrScanMacos,
  pause,
  weeklyRefresh,
}

class CurrentModalValue extends NullableAsyncValue<Modal> {
  CurrentModalValue() : super() {
    load = (Marker m) async => null;
  }
}

class CurrentModalWidgetValue extends AsyncValue<WidgetBuilder> {}

class ModalModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentModalValue());
    await register(CurrentModalWidgetValue());
    await register(ModalActor());
  }
}

class ModalActor with Actor {
  late final _modal = Core.get<CurrentModalValue>();

  @override
  Future<void> onStart(Marker m) async {
    await _modal.fetch(m);

    // Since our bottom sheet displaying library does not support informing
    // us about when the sheet is closed, we use delay to reset state so that
    // we can show another (or same) sheet.
    _modal.onChange.listen((it) async {
      if (it.now != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _modal.change(m, null);
      }
    });
  }
}
