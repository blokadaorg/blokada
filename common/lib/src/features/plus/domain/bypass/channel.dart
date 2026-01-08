part of 'bypass.dart';

@PlatformProvided()
mixin BypassChannel {
  Future<List<InstalledApp>> doGetInstalledApps();
  Future<Uint8List?> doGetAppIcon(String packageName);
}

class InstalledApp {
  final String packageName;
  final String? appName;

  InstalledApp({
    required this.packageName,
    required this.appName,
  });

  static InstalledApp fromOps(String packageName, String? appName) {
    // Platform api likes to return same package name and app name
    // We can handle null app name.
    if (packageName == appName) {
      return InstalledApp(packageName: packageName, appName: null);
    }
    return InstalledApp(
      packageName: packageName,
      appName: appName,
    );
  }

  @override
  String toString() {
    return packageName;
  }
}
