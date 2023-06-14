import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class RateOps {
  @async
  void doShowRateDialog();
}
