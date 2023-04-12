import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PermOps {
  @async
  bool doPrivateDnsEnabled(String tag);

  @async
  void doSetSetPrivateDnsEnabled(String tag);

  @async
  bool doNotificationEnabled();

  @async
  bool doVpnEnabled();
}
