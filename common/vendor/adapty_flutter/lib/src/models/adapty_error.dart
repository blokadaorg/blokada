//
//  adapty_error.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';

part 'private/adapty_error_json_builder.dart';

@immutable
class AdaptyError implements Exception {
  final String message;
  final String? detail;
  final int code;

  const AdaptyError(this.message, this.code, this.detail);

  @override
  String toString() => '(code: $code, message: $message, detail: $detail)';
}
