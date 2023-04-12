import 'package:pigeon/pigeon.dart';

@FlutterApi()
abstract class AccountRefreshEvents {
  @async
  void onRetryInit();
}
