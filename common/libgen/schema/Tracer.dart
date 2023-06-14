import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class TracerOps {
  @async
  void doStartFile(String template);

  @async
  void doSaveBatch(String batch, String mark);
}
