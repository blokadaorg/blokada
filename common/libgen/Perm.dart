import 'package:pigeon/pigeon.dart';

/// Replaces the previous bare-string DNS query which could not distinguish
/// between "the profile is disabled" and "the system doesn't support DNS
/// profiles at all" (e.g. macOS). The three-state kind lets the perm actor
/// decide whether to defer, retry, or settle immediately.
enum PrivateDnsStateKind {
  enabled,
  disabled,
  unavailable,
}

class PrivateDnsState {
  late PrivateDnsStateKind kind;
  late String? serverUrl;

  /// Android only: a hostname is set but the network is not validated,
  /// which is how the system reports a Private DNS server it cannot reach.
  /// Null where unknown.
  late bool? privateDnsBroken;
}

@HostApi()
abstract class PermOps {
  @async
  PrivateDnsState getPrivateDnsState();

  @async
  bool isRunningOnMac();

  @async
  void doSetPrivateDnsEnabled(String tag, String alias);

  @async
  void doSetDns(String tag);

  @async
  bool doNotificationEnabled();

  @async
  bool doVpnEnabled();

  @async
  void doOpenSettings();

  @async
  void doAskNotificationPerms();

  @async
  void doAskVpnPerms();

  @async
  bool doAuthenticate();
}
