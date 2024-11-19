part of 'logger.dart';

mixin LoggerChannel {
  Future<void> doUseFilename(String filename);
  Future<void> doSaveBatch(String batch);
  Future<void> doShareFile();
}

class PlatformLoggerChannel with LoggerChannel {
  late final _platform = LoggerOps();

  @override
  Future<void> doSaveBatch(String batch) => _platform.doSaveBatch(batch);

  @override
  Future<void> doShareFile() => _platform.doShareFile();

  @override
  Future<void> doUseFilename(String filename) =>
      _platform.doUseFilename(filename);
}

class NoOpLoggerChannel with LoggerChannel {
  @override
  Future<void> doSaveBatch(String batch) async {}

  @override
  Future<void> doShareFile() async {}

  @override
  Future<void> doUseFilename(String filename) async {}
}
