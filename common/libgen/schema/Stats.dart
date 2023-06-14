import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class StatsOps {
  @async
  void doBlockedCounterChanged(String blocked);
}
