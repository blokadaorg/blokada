import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class CustomOps {
  @async
  void doCustomAllowedChanged(List<String> allowed);

  @async
  void doCustomDeniedChanged(List<String> denied);
}

@FlutterApi()
abstract class CustomEvents {
  @async
  void onAllow(String domainName);

  @async
  void onDeny(String domainName);

  @async
  void onDelete(String domainName);
}
