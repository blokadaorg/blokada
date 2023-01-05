import 'package:common/service/LogService.dart';
import 'package:flutter/services.dart';

import 'Services.dart';

class EnvService {

  var userAgent = "";

  static const _channel = MethodChannel('env:userAgent');

  late LogService log = Services.instance.log;

  EnvService() {
    _channel.setMethodCallHandler((call) async {
      log.v("Received user agent");
      userAgent = call.arguments;
    });
  }

}
