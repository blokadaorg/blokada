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
