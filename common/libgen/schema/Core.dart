import 'package:pigeon/pigeon.dart';

/// Used by Pigeon to generate the bindings to the platform code.
@HostApi()
abstract class CoreOps {
  // --- Persistence

  @async
  void doSave(String key, String value, bool isSecure, bool isBackup);

  @async
  String doLoad(String key, bool isSecure, bool isBackup);

  @async
  void doDelete(String key, bool isSecure, bool isBackup);

  // --- Logger
  @async
  void doUseFilename(String filename);

  @async
  void doSaveBatch(String batch);

  @async
  void doShareFile();
}
