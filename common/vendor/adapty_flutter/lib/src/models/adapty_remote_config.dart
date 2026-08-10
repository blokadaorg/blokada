import 'package:meta/meta.dart' show immutable;
import 'dart:convert' show json;
import 'private/json_builder.dart';

part 'private/adapty_remote_config_json_builder.dart';

@immutable
class AdaptyRemoteConfig {
  final String locale;
  final String data;

  const AdaptyRemoteConfig._(
    this.locale,
    this.data,
  );

  /// A custom dictionary configured in Adapty Dashboard for this paywall (same as `data`)
  Map<String, dynamic>? get dictionary {
    if (data.isEmpty) return null;
    return json.decode(data);
  }
}
