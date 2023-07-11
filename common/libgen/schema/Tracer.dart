import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class TracerOps {
  @async
  void doStartFile(String filename, String template);

  @async
  void doSaveBatch(String filename, String batch, String mark);

  @async
  void doShareFile(String filename);

  @async
  bool doFileExists(String filename);

  @async
  void doDeleteFile(String filename);
}
