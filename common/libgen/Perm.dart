import 'package:pigeon/pigeon.dart';

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
