import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class LoggerOps {
  @async
  void doUseFilename(String filename);

  @async
  void doSaveBatch(String batch);

  @async
  void doShareFile();
}
