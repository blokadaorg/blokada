//
//  adapty_error.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AdaptySDKNative {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}
