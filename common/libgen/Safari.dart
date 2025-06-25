import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class SafariOps {
  @async
  bool doGetStateOfContentFilter();

  @async
  void doUpdateContentFilterRules(bool filtering);

  @async
  void doOpenPermsFlowForYoutube();

  @async
  void doOpenPermsFlowForContentFilter();
}
