part of 'bypass.dart';

class BypassActor with Actor, Logging {
  late final _channel = Core.get<BypassChannel>();
  late final _bypassedPackages = Core.get<BypassedPackagesValue>();
  late final _bypassedApps = Core.get<BypassedAppsValue>();

  final allApps = <InstalledApp>[];

  @override
  onStart(Marker m) async {
    if (Core.act.platform != PlatformType.android) {
      // Bypass is only supported on Android
      // Ensure dependencies for Plus are loaded (empty list)
      await _bypassedPackages.fetch(m);
      return;
    }

    // Load installed apps when the actor starts
    // Sort by app name, if available, otherwise by package name
    // Put apps without names at the end
    allApps.addAll(await _channel.doGetInstalledApps());
    allApps.sort(_appSorting);

    // Init bypassed packages
    var packages = (await _bypassedPackages.fetch(m));
    packages ??= <String>{};

    if (packages.isEmpty && Core.act.platform == PlatformType.android) {
      log(m).i("No bypassed packages found, using default list for Android");

      // List decided by #133
      await _bypassedPackages.change(m, {
        "com.google.android.projection.gearhead", // Android Auto
        "com.google.android.apps.chromecast.app", // Google Chromecast
        "com.gopro.smarty", // GoPro
        "com.google.android.apps.messaging", // RCS/Jibe messaging services
        "com.sonos.acr", // Sonos
        "com.sonos.acr2", // Sonos
        "com.google.stadia.android", // Stadia
      });
    }

    await refreshList();
  }

  refreshList() async {
    final packages = await _bypassedPackages.now() ?? <String>{};
    var apps = packages
        .map((packageName) => InstalledApp(
              packageName: packageName,
              appName: allApps
                  .firstWhere(
                    (app) => app.packageName == packageName,
                    orElse: () =>
                        InstalledApp(packageName: packageName, appName: null),
                  )
                  .appName,
            ))
        .toList();

    apps.sort(_appSorting);

    _bypassedApps.now = apps;
  }

  // Returns matching apps based on the search string.
  // Will try to do fuzzy match for both package name and app name.
  List<InstalledApp> find(String search) {
    if (search.length < 2) return [];

    final lowerQuery = search.toLowerCase();

    // First, search app names, then package names
    var result = allApps.where((app) {
      return app.appName?.toLowerCase().contains(lowerQuery) ?? false;
    }).toList();

    result += allApps.where((app) {
      return app.packageName.contains(lowerQuery);
    }).toList();

    return result.distinctBy((app) => app.packageName).toList();
  }

  Future<void> setAppBypass(Marker m, String packageName, bool bypassed) async {
    await log(m).trace("setAppBypass", (m) async {
      log(m).i("Setting bypass for $packageName to $bypassed");

      Set<String> apps = <String>{}
        ..addAll((await _bypassedPackages.now()) ?? <String>{});

      if (bypassed) {
        apps.add(packageName);
      } else {
        apps.remove(packageName);
      }

      await _bypassedPackages.change(m, apps);
      await refreshList();
    });
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    return await _channel.doGetAppIcon(packageName);
  }

  int _appSorting(InstalledApp a, InstalledApp b) {
    if (a.appName == null && b.appName == null) {
      return a.packageName.compareTo(b.packageName);
    } else if (a.appName == null) {
      return 1;
    } else if (b.appName == null) {
      return -1;
    } else {
      return a.appName!.toLowerCase().compareTo(b.appName!.toLowerCase());
    }
  }
}
