import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_android.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_ios.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_macos.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
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
  late final _channel = Core.get<PermChannel>();

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
    if (Core.act.isIos) {
      return (context) => FutureBuilder<bool>(
        future: _channel.isRunningOnMac(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return const PrivateDnsSheetMacos();
          } else {
            return const PrivateDnsSheetIos();
          }
        },
      );
    } else {
      return (context) => const PrivateDnsSheetAndroid();
    }
  }
}
