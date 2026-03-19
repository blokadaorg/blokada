import 'dart:convert';

import 'package:common/src/core/core.dart';
import 'package:flutter/services.dart';

enum LaunchReason {
  foregroundInteractive,
  backgroundTask,
}

enum BackgroundTaskSource {
  fcm,
}

enum BootstrapProfile {
  foreground,
  background,
}

class AppLaunchContext {
  static const _channel = MethodChannel('org.blokada/startup');

  final LaunchReason reason;
  final BootstrapProfile profile;
  final String? notificationId;
  final BackgroundTaskSource? backgroundSource;
  final String? fcmEventType;
  final String? payload;

  const AppLaunchContext({
    required this.reason,
    required this.profile,
    this.notificationId,
    this.backgroundSource,
    this.fcmEventType,
    this.payload,
  });

  bool get allowRunApp => profile == BootstrapProfile.foreground;
  bool get allowForegroundData => profile == BootstrapProfile.foreground;
  bool get allowBackgroundEvents => true;
  bool get allowCachedIdentityLoad => true;

  static const foregroundInteractive = AppLaunchContext(
    reason: LaunchReason.foregroundInteractive,
    profile: BootstrapProfile.foreground,
  );

  static Future<AppLaunchContext> load(Marker m) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('consumeLaunchContext');
      if (result is Map) {
        return AppLaunchContext.fromJson(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}

    return foregroundInteractive;
  }

  factory AppLaunchContext.fromJson(Map<String, dynamic> json) {
    final reasonName = _normalizeReasonName(
      (json['reason'] as String?) ?? LaunchReason.foregroundInteractive.name,
    );
    final payload = json['payload'] as String?;
    final resolvedReason = LaunchReason.values.firstWhere(
      (it) => it.name == reasonName,
      orElse: () => LaunchReason.foregroundInteractive,
    );

    final backgroundSourceName = _normalizeBackgroundSourceName(
      json['backgroundSource'] as String?,
    );
    final resolvedBackgroundSource = backgroundSourceName == null
        ? null
        : BackgroundTaskSource.values.firstWhere(
            (it) => it.name == backgroundSourceName,
            orElse: () => BackgroundTaskSource.fcm,
          );
    final explicitEventType = json['fcmEventType'] as String?;
    final parsedEventType = explicitEventType ?? _tryResolveFcmEventType(payload);
    final inferredBackgroundSource = resolvedReason == LaunchReason.backgroundTask
        ? (resolvedBackgroundSource ?? _inferBackgroundSource(parsedEventType, payload))
        : null;
    final profile = resolvedReason == LaunchReason.backgroundTask
        ? BootstrapProfile.background
        : BootstrapProfile.foreground;

    return AppLaunchContext(
      reason: resolvedReason,
      profile: profile,
      notificationId: json['notificationId'] as String?,
      backgroundSource: inferredBackgroundSource,
      fcmEventType: parsedEventType,
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason.name,
      'profile': profile.name,
      'notificationId': notificationId,
      'backgroundSource': backgroundSource?.name,
      'fcmEventType': fcmEventType,
      'payload': payload,
    };
  }

  static BackgroundTaskSource? _inferBackgroundSource(String? eventType, String? payload) {
    if ((eventType != null && eventType.isNotEmpty) || (payload != null && payload.isNotEmpty)) {
      return BackgroundTaskSource.fcm;
    }
    return null;
  }

  static String? _tryResolveFcmEventType(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final type = decoded['type'];
        if (type is String && type.isNotEmpty) {
          return type;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _normalizeReasonName(String value) {
    switch (value) {
      case 'foreground_interactive':
        return LaunchReason.foregroundInteractive.name;
      case 'notification_tap':
        return LaunchReason.foregroundInteractive.name;
      case 'backgroundTask':
      case 'background_task':
        return LaunchReason.backgroundTask.name;
      default:
        return value;
    }
  }

  static String? _normalizeBackgroundSourceName(String? value) {
    switch (value) {
      case null:
        return null;
      case 'fcm_event':
        return BackgroundTaskSource.fcm.name;
      default:
        return value;
    }
  }
}

class BootstrapIdentity {
  final String accountId;
  final String accountType;
  final String? activeUntil;
  final String deviceTag;
  final String? deviceAlias;
  final DateTime updatedAt;

  const BootstrapIdentity({
    required this.accountId,
    required this.accountType,
    required this.activeUntil,
    required this.deviceTag,
    required this.deviceAlias,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'accountId': accountId,
      'accountType': accountType,
      'activeUntil': activeUntil,
      'deviceTag': deviceTag,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };

    if ((deviceAlias ?? '').isNotEmpty) {
      json['deviceAlias'] = deviceAlias;
    }

    return json;
  }

  factory BootstrapIdentity.fromJson(Map<String, dynamic> json) {
    return BootstrapIdentity(
      accountId: json['accountId'] as String,
      accountType: json['accountType'] as String,
      activeUntil: json['activeUntil'] as String?,
      deviceTag: json['deviceTag'] as String,
      deviceAlias: json['deviceAlias'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }
}

class BootstrapIdentityValue extends JsonPersistedValue<BootstrapIdentity> {
  BootstrapIdentityValue() : super('bootstrap:identity', secure: true);

  void onRegister() {
    Core.register<BootstrapIdentityValue>(this);
  }

  @override
  BootstrapIdentity fromJson(Map<String, dynamic> json) {
    return BootstrapIdentity.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(BootstrapIdentity value) {
    return value.toJson();
  }
}
