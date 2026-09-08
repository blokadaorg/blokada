part of 'core.dart';

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
    return getCurrentPlatformType() == PlatformType.android &&
        MediaQuery.of(context).size.height < 750;
  }

  /// Bottom room reserved on short Android phones so content clears the
  /// navigation bar.
  ///
  /// Drops to zero while the soft keyboard is up: the keyboard already covers
  /// the navigation bar, so keeping the reserve would strand a dead band
  /// between the keyboard and whatever sits above it — visible as a gap under
  /// the support chat composer (issue-tracker#152).
  double androidBottomReserve(BuildContext context) {
    if (!isSmallAndroid(context)) return 0;
    return MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 44;
  }
}

enum PlatformType { web, iOS, android, macOS, fuchsia, linux, windows, unknown }
