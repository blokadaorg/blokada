part of 'freemium.dart';

class WeeklyRefreshActor with Logging, Actor {
  late final _notification = Core.get<NotificationActor>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();

  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  late final _lastOpen = Core.get<WeeklyLastOpenValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.weeklyRefresh) {
        _modalWidget.change(m, (context) => const WeeklyRefreshSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, _onForegroundCheckLastOpen);

    final lastOpen = await _lastOpen.fetch(m);
    if (lastOpen == null || lastOpen == DateTime.fromMillisecondsSinceEpoch(0)) {
      // If the last open time is not set at all, user just started using the app
      await _lastOpen.change(m, DateTime.now().add(_getCooldownDuration()));
    }
  }

  _onForegroundCheckLastOpen(StageRouteState route, Marker m) async {
    if (!_account.isFreemium) return;
    if (_account.type.isActive()) return;

    await log(m).trace("onForegroundCheckLastOpen", (m) async {
      // When it goes to bg, we just update the last open time
      // And also schedule the weekly refresh notification
      if (!route.isForeground()) {
        await _lastOpen.change(m, DateTime.now());
        await _notification.show(NotificationId.weeklyRefresh, m,
            when: DateTime.now().add(_getCooldownDuration()));
        return;
      }

      if (!route.isBecameForeground()) return;

      log(m).t("Checking last open time for weekly refresh");

      // If the app is opened after a week, show the weekly refresh modal
      final lastOpen = await _lastOpen.now();
      if (lastOpen == null || DateTime.now().difference(lastOpen) >= _getCooldownDuration()) {
        await _modal.change(m, Modal.weeklyRefresh);
      }

      // Update the last open time
      await _lastOpen.change(m, DateTime.now());
    });
  }

  // Sets the marker so that it will trigger on next Foreground check
  testFlow(Marker m) async {
    await sleepAsync(const Duration(seconds: 5));
    await _lastOpen.change(m, DateTime.fromMicrosecondsSinceEpoch(0));
    await _notification.show(NotificationId.weeklyRefresh, m,
        when: DateTime.now().add(const Duration(seconds: 5)));
  }

  Duration _getCooldownDuration() {
    return Core.act.isRelease ? const Duration(days: 7) : const Duration(minutes: 7);
  }
}
