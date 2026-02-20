part of 'notification.dart';

/// NotificationActor
///
/// Manages notifications, which are used to display information to the user.
/// They are also used to grab user attention to come back to the app, so that
/// we can do stuff in foreground (like refresh account).

class NotificationActor with Logging, Actor {
  // TODO: fix those dependencies
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _publicKey = Core.get<PublicKeyProvidedValue>();
  late final _device = Core.get<DeviceStore>();
  late final _weeklyReport = Core.get<WeeklyReportActor>();

  late final _channel = Core.get<NotificationChannel>();
  late final _json = Core.get<NotificationApi>();
  late final _notifications = Core.get<NotificationsValue>();
  late final WeeklyReportOptOutValue? _weeklyOptOut =
      Core.act.isFamily ? null : Core.get<WeeklyReportOptOutValue>();

  late final _scheduler = Core.get<Scheduler>();

  String? _appleToken;
  String? _fcmToken;
  String? _lastSentFcmKey;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, sendAppleTokenAsync);
    _account.addOn(accountChanged, sendFcmTokenAsync);
    _device.addOn(deviceChanged, sendFcmTokenAsync);
    if (!Core.act.isFamily) {
      _account.addOn(accountChanged, syncNotificationConfigFromBackendAsync);
      _account.addOn(accountIdChanged, syncNotificationConfigFromBackendAsync);
    }
  }

  showWithBody(NotificationId id, Marker m, String body, {DateTime? when}) async {
    return await log(m).trace("showWithPayload", (m) async {
      _addCapped(NotificationEvent.shown(id, when ?? DateTime.now().add(const Duration(seconds: 3)),
          body: body));
      await _updateChannel();
      log(m).pair("notificationId", id);
    });
  }

  show(NotificationId id, Marker m, {DateTime? when}) async {
    return await log(m).trace("show", (m) async {
      log(m).pair("when", when);

      // Always add time to current, otherwise iOS skips it
      _addCapped(
          NotificationEvent.shown(id, when ?? DateTime.now().add(const Duration(seconds: 3))));
      await _updateChannel();
      log(m).pair("notificationId", id);
    });
  }

  // Only dismisses all notifications for now
  dismiss(Marker m, {NotificationId id = NotificationId.all}) async {
    return await log(m).trace("dismissAll", (m) async {
      _addCapped(NotificationEvent.dismissed());
      await _updateChannel();
    });
  }

  onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;

    return await log(m).trace("dismissNotifications", (m) async {
      await dismiss(m);
    });
  }

  sendAppleTokenAsync(Marker m) async {
    if (Core.act.isFamily) return;
    if (_appleToken == null) return;

    // Use scheduler to make sure this does not deadlock
    // (we are in accountChanged callback)
    _scheduler.addOrUpdate(Job(
      "sendAppleToken",
      m,
      before: DateTime.now(),
      callback: sendAppleToken,
    ));
  }

  sendFcmTokenAsync(Marker m) async {
    if (Core.act.isFamily) return;
    if (_fcmToken == null) return;
    final deviceTag = _device.deviceTag;
    final accountId = _account.account?.id;
    if (deviceTag == null || accountId == null) return;
    if (_lastSentFcmKey == _buildFcmKey(accountId, deviceTag, _fcmToken!)) return;

    _scheduler.addOrUpdate(Job(
      "sendFcmToken",
      m,
      before: DateTime.now(),
      callback: sendFcmToken,
    ));
  }

  Future<bool> sendAppleToken(Marker m) async {
    final publicKey = await _publicKey.fetch(m);
    await _json.postToken(publicKey, _appleToken!, m);
    _appleToken = null;
    return false;
  }

  Future<bool> sendFcmToken(Marker m) async {
    final token = _fcmToken;
    final deviceTag = _device.currentDeviceTag;
    final accountId = _account.account?.id;
    if (token == null || accountId == null) return false;
    if (_lastSentFcmKey == _buildFcmKey(accountId, deviceTag, token)) return false;

    await _json.postFcmToken(
      deviceTag,
      token,
      _fcmPlatform(),
      _resolveLocales(),
      m,
    );

    _lastSentFcmKey = _buildFcmKey(accountId, deviceTag, token);
    return false;
  }

  saveAppleToken(String appleToken) async {
    _appleToken = appleToken;
  }

  saveFcmToken(String token) async {
    _fcmToken = token;
  }

  Future<void> syncNotificationConfigFromBackend(Marker m) async {
    final weeklyOptOut = _weeklyOptOut;
    if (weeklyOptOut == null) return;
    if (_account.account == null) return;
    final cfg = await _json.getConfig(m);
    await weeklyOptOut.change(m, cfg.optOut);
  }

  Future<void> syncNotificationConfigFromBackendAsync(Marker m) async {
    await syncNotificationConfigFromBackend(m);
  }

  Future<void> setWeeklyReportEnabled(Marker m, bool enabled) async {
    final weeklyOptOut = _weeklyOptOut;
    if (weeklyOptOut == null) return;

    final optOut = !enabled;
    final previous = await weeklyOptOut.now();
    await weeklyOptOut.change(m, optOut);
    try {
      await _json.putConfig(optOut, m);
    } catch (_) {
      await weeklyOptOut.change(m, previous);
      rethrow;
    }
  }

  String _buildFcmKey(String accountId, String deviceTag, String token) {
    return "$accountId|$deviceTag|$token";
  }

  String _fcmPlatform() {
    if (Platform.isAndroid) return "android";
    return "ios";
  }

  List<String> _resolveLocales() {
    final mapped = <String>[];
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      final tag = _mapLocale(locale);
      if (tag != null && !mapped.contains(tag)) {
        mapped.add(tag);
      }
    }
    if (mapped.isNotEmpty) return mapped;

    final fallback = _mapLocale(I18n.locale);
    if (fallback != null) return [fallback];
    return [supportedLocales.first.toLanguageTag()];
  }

  String? _mapLocale(ui.Locale locale) {
    final exact = supportedLocales.firstWhereOrNull(
      (it) => it.languageCode == locale.languageCode &&
          it.countryCode == locale.countryCode,
    );
    if (exact != null) return exact.toLanguageTag();

    final languageOnly = supportedLocales.firstWhereOrNull(
      (it) => it.languageCode == locale.languageCode &&
          (it.countryCode == null || it.countryCode!.isEmpty),
    );
    if (languageOnly != null) return languageOnly.toLanguageTag();

    final byLanguage =
        supportedLocales.firstWhereOrNull((it) => it.languageCode == locale.languageCode);
    if (byLanguage != null) return byLanguage.toLanguageTag();

    return null;
  }

  notificationTapped(Marker m, String notificationId) async {
    return await log(m).trace("notificationTapped", (m) async {
      final id = NotificationId.values.firstWhereOrNull((it) => it.name == notificationId);

      log(m).pair("id", id);
      final isOnPrivacyPulse = Navigation.lastPath == Paths.privacyPulse;
      if (id == NotificationId.supportNewMessage) {
        // await sleepAsync(const Duration(seconds: 1));
        // await _stage.setRoute(Paths.settings.path, m);
        // await sleepAsync(const Duration(seconds: 3));
        // await _stage.setRoute(Paths.support.path, m);
      } else if (id == NotificationId.weeklyReport) {
        final args = {
          'toplistRange': ToplistRange.weekly,
        };
        if (!isOnPrivacyPulse) {
          await _openPrivacyPulseWithRetry(m, args);
        }
      }
    });
  }

  Future<void> _openPrivacyPulseWithRetry(Marker m, Object? args) async {
    const attempts = 5;
    const delay = Duration(milliseconds: 250);

    for (var i = 0; i < attempts; i++) {
      try {
        await Navigation.open(Paths.privacyPulse, arguments: args);
        return;
      } catch (e, s) {
        final isLastAttempt = i == attempts - 1;
        if (isLastAttempt) {
          log(m).e(msg: "Failed to open Privacy Pulse from notification tap", err: e, stack: s);
          return;
        }
        await sleepAsync(delay);
      }
    }
  }

  handleFcmEvent(Marker m, String payload) async {
    return await log(m).trace("handleFcmEvent", (m) async {
      if (Core.act.isFamily) return;
      final data = _parseFcmPayload(payload);
      if (data == null) return;

      final event = FcmEvent.fromJson(data);
      if (event.type != "weekly_update") return;

      final when = _resolveScheduleHint(event.scheduleHint);
      await log(m).trace('weeklyReport:fcmHandle', (m) async {
        final reportEvent = await _weeklyReport.refreshAndPickForNotification(m);
        if (reportEvent == null) {
          log(m).w('weeklyReport:notification:noEvent');
          return;
        }
        final body = _buildWeeklyReportBody(reportEvent);
        await showWithBody(NotificationId.weeklyReport, m, body, when: when);
      });
    });
  }

  Map<String, dynamic>? _parseFcmPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _buildWeeklyReportBody(WeeklyReportEvent event) {
    // Always show the generic weekly report title in the notification UI.
    final title = weeklyReportTitleKey.i18n;
    final body = event.body;
    final refreshedTitle = weeklyReportRefreshedTitleKey.i18n;
    final refreshedBody = weeklyReportRefreshedBodyKey.i18n;
    return jsonEncode({
      "title": title,
      "body": body,
      "refreshedTitle": refreshedTitle,
      "refreshedBody": refreshedBody,
      "backgroundLeadMs": weeklyReportBackgroundLead.inMilliseconds,
    });
  }

  DateTime? _resolveScheduleHint(String? scheduleHint) {
    return resolveNotificationScheduleHint(scheduleHint, DateTime.now());
  }

  _addCapped(NotificationEvent event) {
    final notifications = _notifications.now.toList();
    notifications.add(event);
    if (notifications.length > 100) {
      notifications.removeAt(0);
    }
    _notifications.now = notifications;
  }

  _updateChannel() async {
    final event = _notifications.now.last;
    if (event.type == NotificationEventType.show) {
      await _channel.doShow(event.id.name, event.when!.toUtc().toIso8601String(), event.body);
    } else if (event.type == NotificationEventType.dismiss) {
      await _channel.doDismissAll();
    }
  }
}

DateTime? resolveNotificationScheduleHint(String? scheduleHint, DateTime now) {
  final trimmed = scheduleHint?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final hour = int.tryParse(trimmed);
  if (hour == null || hour < 0 || hour > 23) return null;

  final localNow = now.toLocal();
  final todayAtHour = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
    hour,
  );
  if (todayAtHour.isAfter(localNow)) return todayAtHour;
  return todayAtHour.add(const Duration(days: 1));
}
