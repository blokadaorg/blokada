import 'package:common/src/shared/navigation.dart';

/// Contract a detail-pane host (WithDetailPane's State) implements so
/// `Navigation.open` can route detail paths into the pane of the screen
/// that actually owns them. Replaces the single global
/// `Navigation.openInTablet` callback, which every two-pane screen
/// overwrote in initState — whichever mounted last won, so opens could
/// land in a stale, background screen's pane.
abstract class DetailPaneHandle {
  /// Only active hosts receive paths: mounted, on the current route, and
  /// currently laid out in two-pane (expanded) mode. In compact mode the
  /// same path falls through to a normal full-screen push.
  bool get isActive;

  /// Whether this host renders the path in its pane. Host-scoped so the
  /// owning screen decides, replacing the global `Paths.openInTablet` flag.
  bool accepts(Paths path);

  void show(Paths path, Object? arguments);
}

/// DI singleton (`Core.get<DetailPaneHosts>()`). Hosts register in
/// initState and unregister in dispose; the most recently registered
/// active host that accepts a path wins, so a screen pushed on top of
/// another takes precedence while both are alive.
class DetailPaneHosts {
  final List<DetailPaneHandle> _hosts = [];

  void register(DetailPaneHandle host) {
    _hosts.remove(host);
    _hosts.add(host);
  }

  void unregister(DetailPaneHandle host) {
    _hosts.remove(host);
  }

  /// Returns true if a host took the path; false means the caller should
  /// push it as a regular route.
  bool openInPane(Paths path, Object? arguments) {
    for (final host in _hosts.reversed) {
      if (host.isActive && host.accepts(path)) {
        host.show(path, arguments);
        return true;
      }
    }
    return false;
  }
}
