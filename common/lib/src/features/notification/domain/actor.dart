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
  late final _stats = Core.get<StatsStore>();
  Paths? _pendingNotificationPath;
  Object? _pendingNotificationArgs;
  Future<void> Function(Marker)? _pendingNotificationAction;
  var _notificationNavInFlight = false;

  // When a user taps the weekly-report "Turn off" notification action we
  // navigate to Settings first and defer the actual toggle flip until the
  // screen has rendered, so the animation is visible. The widget consumes
  // this flag via [consumePendingOptOutFromNotification]; a fallback timer
  // in [notificationTapped] guarantees the opt-out lands even if the
  // settings screen never mounts.
  var _pendingOptOutFromNotification = false;

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
      await _tryOpenPendingNotification(m, trigger: "onStart");
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
      await _tryOpenPendingNotification(m, trigger: "routeChanged");
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

  // Called by the Settings screen after it has mounted following a
  // notification opt-out action. Safe to call any time — no-ops if no
  // notification-driven opt-out is pending. When pending, waits a short
  // beat so the toggle's flip animation lands after the iOS app-launch /
  // route-transition animation has settled, rather than playing invisibly
  // while the route is still sliding in.
  Future<bool> consumePendingOptOutFromNotification(Marker m) async {
    if (!_pendingOptOutFromNotification) return false;
    _pendingOptOutFromNotification = false;
    await sleepAsync(const Duration(milliseconds: 700));
    await _onWeeklyReportOptOutAction(m);
    return true;
  }

  Future<void> _onWeeklyReportOptOutAction(Marker m) async {
    await log(m).trace('weeklyReport:optOutFromNotification', (m) async {
      try {
        await setWeeklyReportEnabled(m, false);
        log(m).i('weeklyReport:optOutFromNotification:ok');
      } catch (e) {
        log(m).e(msg: 'weeklyReport:optOutFromNotification:failed: $e');
      }
    });
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
      // Native side passes "id" for body taps and "id|ACTION" for custom
      // notification action buttons (iOS UNNotificationAction, Android
      // NotificationCompat.Action).
      final parts = notificationId.split('|');
      final rawId = parts[0];
      final actionId = parts.length > 1 ? parts[1] : null;
      final id = NotificationId.values.firstWhereOrNull((it) => it.name == rawId);

      log(m).pair("notificationId", notificationId);
      log(m).pair("id", id);
      log(m).pair("actionId", actionId);

      if (id == NotificationId.weeklyReport && actionId == 'OPT_OUT') {
        // Set a pending marker, navigate to Settings, and let the settings
        // screen drive the flip after it has rendered — that gives the user
        // a deterministic "toggle was ON, now animates to OFF" cue without
        // depending on hardcoded delays that miss cold-start times.
        _pendingOptOutFromNotification = true;
        await _queueNotificationNavigation(
          m,
          path: Paths.settings,
          trigger: "notificationTapped:optOut",
        );
        // Safety: if the settings screen never mounts (e.g. user dismisses
        // the route immediately, or the actor is invoked outside the normal
        // UI lifecycle in a test), still honor the explicit user intent.
        Future.delayed(const Duration(seconds: 3), () async {
          if (_pendingOptOutFromNotification) {
            await consumePendingOptOutFromNotification(m);
          }
        });
        return;
      }

      if (id == NotificationId.accountRescue) {
        // The whole point of the rescue push is to get the user back to the
        // store subscription screen, so the tap goes straight there instead of
        // opening any in-app route.
        await _queueNotificationAction(
          m,
          trigger: "notificationTapped:accountRescue",
          action: _openManageSubscriptions,
        );
        return;
      }

      if (id == NotificationId.accountExpired) {
        // Lapsed users land on the win-back placement; Adapty applies the
        // configured Apple/Google win-back offer to eligible profiles.
        await _queueNotificationAction(
          m,
          trigger: "notificationTapped:winback",
          action: _openWinbackPaywall,
        );
        return;
      }

      final isOnPrivacyPulse = Navigation.lastPath == Paths.privacyPulse;
      if (id == NotificationId.supportNewMessage) {
        // await sleepAsync(const Duration(seconds: 1));
        // await _stage.setRoute(Paths.settings.path, m);
        // await sleepAsync(const Duration(seconds: 3));
        // await _stage.setRoute(Paths.support.path, m);
      } else if (id == NotificationId.activityLoggingReminder) {
        await _queueNotificationNavigation(
          m,
          path: Paths.settingsRetention,
          trigger: "notificationTapped",
        );
      } else if (id == NotificationId.weeklyReport) {
        final args = {
          'toplistRange': ToplistRange.weekly,
        };
        if (!isOnPrivacyPulse) {
          await _queueNotificationNavigation(
            m,
            path: Paths.privacyPulse,
            args: args,
            trigger: "notificationTapped",
          );
        }
      }
    });
  }

  Future<void> _queueNotificationNavigation(
    Marker m, {
    required Paths path,
    Object? args,
    required String trigger,
  }) async {
    _pendingNotificationPath = path;
    _pendingNotificationArgs = args;
    if (_stage.route.isForeground()) {
      await _tryOpenPendingNotification(m, trigger: trigger);
    }
  }

  // Like _queueNotificationNavigation but for side effects that need the
  // foreground modules started (links are populated by LinkActor.onStart,
  // paywalls need PaymentActor). Runs once the app becomes foreground.
  Future<void> _queueNotificationAction(
    Marker m, {
    required String trigger,
    required Future<void> Function(Marker) action,
  }) async {
    _pendingNotificationAction = action;
    if (_stage.route.isForeground()) {
      await _tryOpenPendingNotification(m, trigger: trigger);
    }
  }

  Future<void> _tryOpenPendingNotification(Marker m, {required String trigger}) async {
    final action = _pendingNotificationAction;
    if (action != null) {
      _pendingNotificationAction = null;
      // Deliberately not awaited. This drain also runs from onStart, which
      // executes inside the sequential module start loop — and the module the
      // action waits for (LinkModule) starts later in that same loop, so
      // awaiting the retry here would block the startup it depends on and then
      // time out. The retry never throws, so nothing is left unhandled.
      unawaited(_runNotificationActionWithRetry(m, action));
      log(m).pair("notificationActionTrigger", trigger);
    }

    final path = _pendingNotificationPath;
    if (path == null) return;
    if (_notificationNavInFlight) return;

    if (Navigation.lastPath == path) {
      _pendingNotificationPath = null;
      _pendingNotificationArgs = null;
      return;
    }

    _notificationNavInFlight = true;
    final args = _pendingNotificationArgs;
    _pendingNotificationPath = null;
    _pendingNotificationArgs = null;
    try {
      await _openNotificationWithRetry(m, path, args);
    } finally {
      _notificationNavInFlight = false;
      log(m).pair("notificationNavTrigger", trigger);
      log(m).pair("notificationNavPath", path);
    }
  }

  // A tear-off rather than an inline closure, so the action runs with the
  // marker of whichever drain finally executes it, not the one from tap time.
  Future<void> _openManageSubscriptions(Marker m) =>
      _stage.openLink(LinkId.manageSubscriptions, m);

  // Same tear-off reasoning as above. openPaymentScreen awaits the payment
  // preload completer, so a cold-start tap presents once Adapty is ready.
  Future<void> _openWinbackPaywall(Marker m) async {
    // A cold start from the expired notification also runs the account refresh,
    // which shows the one-shot accountExpired modal at the same moment — and two
    // presentations racing on iOS can leave the paywall never shown, so retire
    // the modal and wait for the dismissal before presenting Adapty.
    if (_stage.route.modal == StageModal.accountExpired) {
      await _stage.dismissModal(m);
    }
    await _payment.openPaymentScreen(m, placement: Placement.winback);
  }

  // The tap can arrive before the module backing the action has started:
  // NotificationModule is registered — and therefore started — ahead of
  // LinkModule (see modules.dart), and StageStore.openLink throws
  // "Link not found" until LinkActor has populated its link map. Retrying
  // across that start window keeps a cold-start tap from being dropped.
  Future<void> _runNotificationActionWithRetry(
      Marker m, Future<void> Function(Marker) action) async {
    const attempts = 20;
    const delay = Duration(milliseconds: 500);

    for (var i = 0; i < attempts; i++) {
      try {
        await action(m);
        return;
      } catch (e, s) {
        final isLastAttempt = i == attempts - 1;
        if (isLastAttempt) {
          log(m).e(msg: "Failed to run notification action", err: e, stack: s);
          return;
        }
        await sleepAsync(delay);
      }
    }
  }

  Future<void> _openNotificationWithRetry(Marker m, Paths path, Object? args) async {
    const attempts = 5;
    const delay = Duration(milliseconds: 250);

    for (var i = 0; i < attempts; i++) {
      try {
        await Navigation.open(path, arguments: args);
        return;
      } catch (e, s) {
        final isLastAttempt = i == attempts - 1;
        if (isLastAttempt) {
          log(m).e(msg: "Failed to open notification destination", err: e, stack: s);
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
      if (_account.account == null) {
        log(m)
          ..w('Skipping background notification event without account context')
          ..pair('eventType', event.type)
          ..pair('eventId', event.eventId);
        return;
      }

      if (event.type == "account_expiry") {
        await _accountRefresh.onAccountExpiryEvent(m);
        log(m).i("accountExpiry:fcmHandle");
        log(m).pair("event_id", event.eventId);
        return;
      }
      if (event.type == "account_rescue") {
        await _handleAccountRescue(m, event);
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
        if (!reportEvent.isPostable) {
          log(m)
            ..w('weeklyReport:notification:notPostable')
            ..pair('eventId', reportEvent.id)
            ..pair('type', reportEvent.type.name);
          return;
        }
        final body = _buildWeeklyReportBody(reportEvent);
        await showWithBody(NotificationId.weeklyReport, m, body, when: when);
      });
    });
  }

  // The retention rescue push: the server knows only that the subscription is
  // lapsing, so the app fills in the fresh countdown and the blocked total.
  Future<void> _handleAccountRescue(Marker m, FcmEvent event) async {
    await log(m).trace('accountRescue:fcmHandle', (m) async {
      log(m).pair('event_id', event.eventId);
      // Fresh expiry is needed for the countdown; the same fetch also drops
      // the message if the subscription renewed after the server sent it.
      // A stalled fetch must not fall through to the cached account: a stale
      // active_until would put a wrong day count in front of the user, so a
      // slow backend drops the push instead.
      try {
        await _account.fetch(m).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        log(m).w('accountRescue:accountFetchTimeout');
        return;
      }
      final activeUntil = _account.account?.jsonAccount.activeUntil;
      final days = resolveRescueDays(
        activeUntil == null ? null : DateTime.tryParse(activeUntil),
        DateTime.now(),
      );
      if (days == null) {
        log(m).w('accountRescue:notification:notExpiring');
        return;
      }

      int? totalBlocked;
      try {
        await _stats.fetch(m).timeout(const Duration(seconds: 8));
        // "Blokada has blocked 0 ads and trackers" argues against renewing, so
        // a device that never filtered anything gets the stats-free copy.
        final blocked = _stats.stats.totalBlocked;
        if (blocked > 0) totalBlocked = blocked;
      } catch (e) {
        log(m).w('accountRescue:stats:unavailable: $e');
      }

      final devices = resolveRescueDevices(event.extrasMap['devices']);
      final body = buildAccountRescueBody(totalBlocked: totalBlocked, devices: devices, days: days);
      final when = _resolveScheduleHint(event.scheduleHint);
      await showWithBody(NotificationId.accountRescue, m, body, when: when);
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
        await _channel.doDismissDeliveredAll();
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

/// Longest countdown a rescue notification may claim. Anything further out
/// means the subscription renewed after the server sent the rescue.
const rescueMaxDays = 30;

/// Days of protection left, rounded up. Null when the account is already
/// expired (the expiry notification covers that) or when expiry is more than
/// [rescueMaxDays] away, which means the subscription renewed after the
/// server sent the rescue and the message is stale.
int? resolveRescueDays(DateTime? activeUntil, DateTime now) {
  if (activeUntil == null) return null;
  final remaining = activeUntil.difference(now);
  if (remaining.isNegative || remaining == Duration.zero) return null;
  final days = (remaining.inMinutes / Duration.minutesPerDay).ceil();
  // Under a minute left rounds down to zero, and "ends in 0 days" reads broken.
  if (days <= 0 || days > rescueMaxDays) return null;
  return days;
}

/// The device count for the rescue copy. The server sends it as a free-form
/// extras string, so anything that is not a positive number (absent, "null",
/// "0", junk) falls back to one device rather than reaching the notification.
String resolveRescueDevices(String? raw) {
  final parsed = int.tryParse(raw?.trim() ?? "");
  if (parsed == null || parsed <= 0) return "1";
  return "$parsed";
}

/// The rescue notification payload, encoded the same way as the weekly report
/// one: the native side renders the `title` / `body` pair out of it. Falls back
/// to the stats-free copy when the blocked total could not be fetched.
String buildAccountRescueBody({
  required int? totalBlocked,
  required String devices,
  required int days,
}) {
  final title = "notification account rescue title".i18n;
  final body = totalBlocked == null
      ? "notification account rescue body short".i18n.withParams(devices, days)
      : "notification account rescue body".i18n.withParams(totalBlocked, devices, days);
  return jsonEncode({"title": title, "body": body});
}
