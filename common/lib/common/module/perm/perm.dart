import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/widget/private_dns/private_dns_sheet_android.dart';
import 'package:common/common/widget/private_dns/private_dns_sheet_ios.dart';
import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

// Rename to PermModule when merged with the one from Family
class CommonPermModule with Module {
  @override
  onCreateModule() async {
    await register(CommonPermSheetActor());
  }
}

class CommonPermSheetActor with Actor {
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardPrivateDns) {
        _modalWidget.change(it.m, _getBuilder());
      }
    });
  }

  WidgetBuilder _getBuilder() {
    if (Core.act.platform == PlatformType.iOS) {
      return (context) => const PrivateDnsSheetIos();
    } else {
      return (context) => const PrivateDnsSheetAndroid();
    }
  }
}
