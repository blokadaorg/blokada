import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

enum Modal {
  onboardPrivateDns,
  plusDeviceLimitReached,
  familyAddProfile,
  familyLinkDevice,
}

class CurrentModalValue extends NullableAsyncValue<Modal> {}

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
