import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PlusOps {
  @async
  void doPlusEnabledChanged(bool plusEnabled);
}
