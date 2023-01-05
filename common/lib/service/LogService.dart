import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LogService {

  static const logChannel = MethodChannel('log');

  v(String msg) {
    debugPrint(msg);
    logChannel.invokeMethod("v", msg);
  }

  e(String msg) {
    debugPrint("Error: $msg");
    logChannel.invokeMethod("e", msg);
  }
}