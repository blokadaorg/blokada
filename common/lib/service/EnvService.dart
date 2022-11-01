import 'package:flutter/services.dart';

class EnvService {

  var userAgent = "";

  static const _channel = MethodChannel('env:userAgent');

  EnvService() {
    _channel.setMethodCallHandler((call) async {
      print("Received user agent");
      userAgent = call.arguments;
    });
  }

}
