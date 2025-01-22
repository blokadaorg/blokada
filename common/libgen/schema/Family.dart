import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class FamilyOps {
  @async
  void doShareUrl(String url);
}
