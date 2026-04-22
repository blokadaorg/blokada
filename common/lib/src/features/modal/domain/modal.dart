import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';

/// This is the newer approach to showing modals / dialogs.
/// Old stuff (from StageStore and Navigation) should be merged and removed.

enum Modal {
  adaptyPaywall,
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

    // Note: clearing of [_modal] after a sheet is dismissed is owned by
    // BottomManagerSheet (which awaits the sheet's dismiss future and clears
    // the value then). Previously this actor cleared the value after a fixed
    // 500ms delay as a workaround for the missing dismiss callback, but that
    // made the dedup checks against [_modal.present] unreliable and could
    // lead to multiple sheets being stacked on top of each other when the
    // same modal type was requested multiple times during cold start.
  }
}
