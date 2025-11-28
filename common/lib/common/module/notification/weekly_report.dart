part of 'notification.dart';

const Duration weeklyReportInterval = Duration(minutes: 20);
const Duration weeklyReportBackgroundLead = Duration(minutes: 5);

class WeeklyReportScheduleValue extends StringifiedPersistedValue<DateTime> {
  WeeklyReportScheduleValue() : super('notification:weekly_report:scheduled_at');

  @override
  DateTime fromStringified(String value) => DateTime.parse(value);

  @override
  String toStringified(DateTime value) => value.toIso8601String();
}

class WeeklyReportContentPayload {
  final String title;
  final String body;
  final String refreshedTitle;
  final String refreshedBody;
  final Duration backgroundLead;

  WeeklyReportContentPayload({
    required this.title,
    required this.body,
    required this.refreshedTitle,
    required this.refreshedBody,
    required this.backgroundLead,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'refreshedTitle': refreshedTitle,
        'refreshedBody': refreshedBody,
        'backgroundLeadMs': backgroundLead.inMilliseconds,
      };

  static WeeklyReportContentPayload generic() => WeeklyReportContentPayload(
        title: 'Weekly privacy report',
        body: 'See this week\'s highlights from your protection.',
        refreshedTitle: 'Traffic increased refresh',
        refreshedBody: 'Your traffic increased by 4% this week (bg)',
        backgroundLead: weeklyReportBackgroundLead,
      );

  static WeeklyReportContentPayload updated() => WeeklyReportContentPayload(
        title: 'Traffic increased',
        body: 'Your traffic increased by 420% this week',
        refreshedTitle: 'Traffic increased refresh',
        refreshedBody: 'Your traffic increased by 4% this week (bg)',
        backgroundLead: weeklyReportBackgroundLead,
      );
}

class WeeklyReportActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _notification = Core.get<NotificationActor>();
  late final _scheduledAt = Core.get<WeeklyReportScheduleValue>();

  @override
  onStart(Marker m) async {
    if (Core.act.isFamily) return;
    _stage.addOnValue(routeChanged, _onRouteChanged);
    await _ensureScheduled(m);
  }

  Future<void> _onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;
    await _ensureScheduled(m);
  }

  Future<void> _ensureScheduled(Marker m) async {
    await log(m).trace('weeklyReport:onAppOpen', (m) async {
      final now = DateTime.now();
      final stored = await _scheduledAt.fetch(m);
      final target = _pickTarget(now, stored);
      final isInitialSchedule = stored == null || stored.isBefore(now);
      final payload = isInitialSchedule
          ? WeeklyReportContentPayload.generic()
          : WeeklyReportContentPayload.updated();

      log(m)
        ..pair('storedAt', stored?.toIso8601String())
        ..pair('scheduledAt', target.toIso8601String())
        ..pair('isInitialSchedule', isInitialSchedule);

      await _scheduledAt.change(m, target);
      await _logBackgroundSchedule(m, target, payload);
      await _notification.showWithBody(
        NotificationId.weeklyReport,
        m,
        jsonEncode(payload.toJson()),
        when: target,
      );
    });
  }

  Future<void> _logBackgroundSchedule(
    Marker m,
    DateTime target,
    WeeklyReportContentPayload payload,
  ) async {
    final backgroundAt = target.subtract(payload.backgroundLead);
    log(m)
      ..pair('backgroundLeadMs', payload.backgroundLead.inMilliseconds)
      ..pair('backgroundAt', backgroundAt.toIso8601String());
  }

  DateTime _pickTarget(DateTime now, DateTime? stored) {
    if (stored == null) return now.add(weeklyReportInterval);
    if (stored.isAfter(now)) return stored;
    return now.add(weeklyReportInterval);
  }
}
