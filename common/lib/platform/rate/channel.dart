part of 'rate.dart';

class PlatformRateChannel with RateChannel {
  late final _ops = RateOps();

  @override
  Future<void> doShowRateDialog() => _ops.doShowRateDialog();
}

class NoOpRateChanel with RateChannel {
  @override
  Future<void> doShowRateDialog() => Future.value();
}
