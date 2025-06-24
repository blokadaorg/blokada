part of 'blockaweb.dart';

class SafariContentActor with Actor, Logging {
  late final _app = Core.get<AppStore>();

  bool _safariActiveMock = false;

  @override
  onStart(Marker m) async {}

  Future<bool> needsOnboard(Marker m) async {
    return !_safariActiveMock;
  }

  markAsActive() async {
    await log(Markers.userTap).trace("markAsActive", (m) async {
      _safariActiveMock = true;
      await _app.reconfiguring(m);

      // Needs to happen after the wait from unpauseApp
      // MARK1
      await sleepAsync(const Duration(seconds: 3));

      await _app.freemiumActivated(m, true);
    });
  }
}
