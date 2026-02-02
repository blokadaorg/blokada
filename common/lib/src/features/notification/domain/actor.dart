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
  var _pendingPrivacyPulseNav = false;
  Object? _pendingPrivacyPulseArgs;

  late final _channel = Core.get<NotificationChannel>();
  late final _json = Core.get<NotificationApi>();
  late final _notifications = Core.get<NotificationsValue>();

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

      if (_pendingPrivacyPulseNav) {
        _pendingPrivacyPulseNav = false;
        final args = _pendingPrivacyPulseArgs;
        _pendingPrivacyPulseArgs = null;
        Navigation.open(Paths.privacyPulse, arguments: args);
      }
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
      if (id == NotificationId.supportNewMessage) {
        // await sleepAsync(const Duration(seconds: 1));
        // await _stage.setRoute(Paths.settings.path, m);
        // await sleepAsync(const Duration(seconds: 3));
        // await _stage.setRoute(Paths.support.path, m);
      } else if (id == NotificationId.weeklyReport) {
        final args = {'toplistRange': ToplistRange.weekly};
        if (_stage.route.isForeground()) {
          Navigation.open(Paths.privacyPulse, arguments: args);
        } else {
          _pendingPrivacyPulseNav = true;
          _pendingPrivacyPulseArgs = args;
        }
      }
    });
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
    final title = event.title;
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
    final now = DateTime.now();
    return now.add(const Duration(minutes: 2));
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
