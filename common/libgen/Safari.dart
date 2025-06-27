import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class SafariOps {
  @async
  void doOpenSafariSetup();
}
