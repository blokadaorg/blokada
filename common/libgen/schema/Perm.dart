import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PermOps {
  @async
  bool doPrivateDnsEnabled(String tag, String alias);

  @async
  void doSetSetPrivateDnsEnabled(String tag, String alias);

  @async
  bool doNotificationEnabled();

  @async
  bool doVpnEnabled();
}
