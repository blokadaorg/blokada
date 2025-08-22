import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PermOps {
  @async
  String getPrivateDnsSetting();

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
