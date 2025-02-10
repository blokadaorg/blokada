import 'package:common/common/widget/private_dns/private_dns_sheet_android.dart';
import 'package:common/common/widget/private_dns/private_dns_sheet_ios.dart';
import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

// Rename to PermModule when merged with the one from Family
class CommonPermModule with Module {
  @override
  onCreateModule() async {
    if (Core.act.platform == PlatformType.iOS) {
      await register<StatefulWidget>(const PrivateDnsSheetIos(),
          tag: "privateDnsSheet");
    } else {
      await register<StatefulWidget>(const PrivateDnsSheetAndroid(),
          tag: "privateDnsSheet");
    }
  }
}
