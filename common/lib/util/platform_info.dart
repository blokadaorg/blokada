import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class PlatformInfo {
  bool isDesktopOS() =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  bool isAppOS() => Platform.isMacOS || Platform.isAndroid;

  bool isWeb() => kIsWeb;

  bool isDesktopOrWeb() => isWeb() || isDesktopOS();

  PlatformType getCurrentPlatformType() {
    if (kIsWeb) {
      return PlatformType.web;
    }
    if (Platform.isMacOS) {
      return PlatformType.macOS;
    }
    if (Platform.isFuchsia) {
      return PlatformType.fuchsia;
    }
    if (Platform.isLinux) {
      return PlatformType.linux;
    }
    if (Platform.isWindows) {
      return PlatformType.windows;
    }
    if (Platform.isIOS) {
      return PlatformType.iOS;
    }
    if (Platform.isAndroid) {
      return PlatformType.android;
    }
    return PlatformType.unknown;
  }

  bool isSmallAndroid(BuildContext context) {
    print(MediaQuery.of(context).size.height);
    return getCurrentPlatformType() == PlatformType.android &&
        MediaQuery.of(context).size.height < 750;
  }
}

enum PlatformType { web, iOS, android, macOS, fuchsia, linux, windows, unknown }
