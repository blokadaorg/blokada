import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class CustomOps {
  @async
  void doCustomAllowedChanged(List<String> allowed);

  @async
  void doCustomDeniedChanged(List<String> denied);
}
