part of 'notification.dart';

/// NotificationActor
///
/// Manages notifications, which are used to display information to the user.
/// They are also used to grab user attention to come back to the app, so that
/// we can do stuff in foreground (like refresh account).

class NotificationActor with Logging, Actor {
  static const _activityLoggingReminderDelay = Duration(minutes: 1);
  static const _activityLoggingReminderBody =
      "Enable activity logging to receive your weekly Privacy Pulse reports.";

  // TODO: fix those dependencies
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _accountRefresh = Core.get<AccountRefreshStore>();
  late final _device = Core.get<DeviceStore>();
  late final _payment = Core.get<PaymentActor>();
  late final _weeklyReport = Core.get<WeeklyReportActor>();
  var _pendingPrivacyPulseNav = false;
  Object? _pendingPrivacyPulseArgs;
  var _privacyPulseNavInFlight = false;

  late final _channel = Core.get<NotificationChannel>();
  late final _json = Core.get<NotificationApi>();
  late final _notifications = Core.get<NotificationsValue>();
  late final WeeklyReportOptOutValue? _weeklyOptOut =
      Core.act.isFamily ? null : Core.get<WeeklyReportOptOutValue>();

  late final _scheduler = Core.get<Scheduler>();

  String? _fcmToken;
  String? _lastSentFcmKey;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, sendFcmTokenAsync);
    _device.addOn(deviceChanged, sendFcmTokenAsync);
    _device.addOn(deviceChanged, _onDeviceChanged);
    _payment.addOnValue(paymentSuccessful, _onPaymentSuccessful);
    if (!Core.act.isFamily) {
      _account.addOn(accountChanged, syncNotificationConfigFromBackendAsync);
      _account.addOn(accountIdChanged, syncNotificationConfigFromBackendAsync);
    }
    if (_stage.route.isForeground()) {
      await _tryOpenPendingPrivacyPulse(m, trigger: "onStart");
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
    return await log(m).trace("dismiss", (m) async {
      if (id == NotificationId.all) {
        _addCapped(NotificationEvent.dismissed());
      } else {
        _addCapped(NotificationEvent.dismissed(id: id));
      }
      await _updateChannel();
    });
  }

  onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;

    return await log(m).trace("dismissNotifications", (m) async {
      await dismiss(m);
      await _tryOpenPendingPrivacyPulse(m, trigger: "routeChanged");
    });
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
      (it) => it.languageCode == locale.languageCode && it.countryCode == locale.countryCode,
    );
    if (exact != null) return exact.toLanguageTag();

    final languageOnly = supportedLocales.firstWhereOrNull(
      (it) =>
          it.languageCode == locale.languageCode &&
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
      } else if (id == NotificationId.activityLoggingReminder) {
        await Navigation.open(Paths.settingsRetention);
      } else if (id == NotificationId.weeklyReport) {
        final args = {
          'toplistRange': ToplistRange.weekly,
        };
        if (!isOnPrivacyPulse) {
          _pendingPrivacyPulseNav = true;
          _pendingPrivacyPulseArgs = args;
          if (_stage.route.isForeground()) {
            await _tryOpenPendingPrivacyPulse(m, trigger: "notificationTapped");
          }
        }
      }
    });
  }

  Future<void> _tryOpenPendingPrivacyPulse(Marker m, {required String trigger}) async {
    if (!_pendingPrivacyPulseNav) return;
    if (_privacyPulseNavInFlight) return;

    final isOnPrivacyPulse = Navigation.lastPath == Paths.privacyPulse;
    if (isOnPrivacyPulse) {
      _pendingPrivacyPulseNav = false;
      _pendingPrivacyPulseArgs = null;
      return;
    }

    _privacyPulseNavInFlight = true;
    final args = _pendingPrivacyPulseArgs;
    _pendingPrivacyPulseNav = false;
    _pendingPrivacyPulseArgs = null;
    try {
      await _openPrivacyPulseWithRetry(m, args);
    } finally {
      _privacyPulseNavInFlight = false;
      log(m).pair("privacyPulseNavTrigger", trigger);
    }
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
      if (event.type == "account_expiry") {
        await _accountRefresh.onAccountExpiryEvent(m);
        log(m).i("accountExpiry:fcmHandle");
        log(m).pair("event_id", event.eventId);
        return;
      }
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

  Future<void> _onPaymentSuccessful(bool restore, Marker m) async {
    if (restore || Core.act.isFamily) return;

    await log(m).trace("activityLoggingReminder:onPaymentSuccessful", (m) async {
      await _device.fetch(m, force: true);
      if (_device.retention?.isEnabled() ?? false) {
        await dismiss(m, id: NotificationId.activityLoggingReminder);
        return;
      }

      await showWithBody(
        NotificationId.activityLoggingReminder,
        m,
        _activityLoggingReminderBody,
        when: DateTime.now().add(_activityLoggingReminderDelay),
      );
    });
  }

  Future<void> _onDeviceChanged(Marker m) async {
    if (!(_device.retention?.isEnabled() ?? false)) return;
    await dismiss(m, id: NotificationId.activityLoggingReminder);
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
      if (event.id == NotificationId.all) {
        await _channel.doDismissAll();
      } else {
        await _channel.doCancel(event.id.name);
      }
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
