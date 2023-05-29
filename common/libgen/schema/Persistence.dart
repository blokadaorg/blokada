import 'package:pigeon/pigeon.dart';

/// Used by Pigeon to generate the bindings to the platform code. Make sure to
/// also change PersistenceChannelSpec (and rerun Pigeon) if you change this one.
@HostApi()
abstract class PersistenceOps {
  @async
  void doSave(String key, String value, bool isSecure, bool isBackup);

  @async
  String doLoad(String key, bool isSecure, bool isBackup);

  @async
  void doDelete(String key, bool isSecure, bool isBackup);
}
