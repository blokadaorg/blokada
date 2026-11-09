part of 'home.dart';

/// The kinds of headline the daily Home (#460) can lead with. Company names
/// (#459) are not built yet, so these come from data the app already loads.
enum HomeHeadlineKind {
  /// The most blocked domain in the last 24 hours. Needs activity logging.
  topBlocked,

  /// The hour of the last 24 with the most blocks.
  busiestHour,

  /// A Privacy Pulse weekly event (#220): week-over-week changes, so only
  /// accounts with two weeks of data have one.
  weekly,
}

/// One headline candidate. It carries the numbers, not the text: the card
/// words it in the current language and keeps the numbers live while the
/// choice of headline stays fixed for the day.
class HomeHeadline {
  final HomeHeadlineKind kind;

  /// How strongly this candidate wants the slot; higher wins.
  final double score;

  /// [HomeHeadlineKind.topBlocked]: the domain.
  final String? domain;

  /// Blocked requests: for the domain or in the busiest hour.
  final int count;

  /// [HomeHeadlineKind.busiestHour]: the start of the hour.
  final DateTime? hourStart;

  /// [HomeHeadlineKind.weekly]: the event, already worded.
  final WeeklyReportEvent? weekly;

  const HomeHeadline({
    required this.kind,
    required this.score,
    this.domain,
    this.count = 0,
    this.hourStart,
    this.weekly,
  });
}

/// Fewer blocks than this in the last 24 hours make no busiest hour worth
/// a headline.
const _minBlocksForBusiestHour = 10;

/// The busiest hour of the last 24, from the hourly histogram where the last
/// bucket is the current hour ([now] rounded down).
HomeHeadline? busiestHourHeadline(UiStats stats, DateTime now) {
  final histogram = stats.blockedHistogram;
  if (histogram.isEmpty || stats.dayBlocked < _minBlocksForBusiestHour) return null;
  var best = 0;
  for (var i = 1; i < histogram.length; i++) {
    if (histogram[i] > histogram[best]) best = i;
  }
  if (histogram[best] <= 0) return null;
  final currentHour = DateTime(now.year, now.month, now.day, now.hour);
  final hourStart = currentHour.subtract(Duration(hours: histogram.length - 1 - best));
  return HomeHeadline(
    kind: HomeHeadlineKind.busiestHour,
    score: 50,
    count: histogram[best],
    hourStart: hourStart,
  );
}

/// The most blocked domain in the last 24 hours, from the toplist.
HomeHeadline? topBlockedHeadline(String? domain, int count) {
  if (domain == null || domain.isEmpty || count <= 0) return null;
  return HomeHeadline(kind: HomeHeadlineKind.topBlocked, score: 70, domain: domain, count: count);
}

/// A weekly event as a headline, ranked below the daily kinds: it changes
/// once a week, so it should not hold the slot every day.
HomeHeadline weeklyHeadline(WeeklyReportEvent event) {
  return HomeHeadline(kind: HomeHeadlineKind.weekly, score: 30, weekly: event);
}

/// Which kind led on which day, kept so the headline does not change through
/// the day as numbers move and so the next day leads with something else.
class HomeHeadlinePick {
  /// Local date, yyyy-MM-dd.
  final String day;
  final HomeHeadlineKind kind;

  const HomeHeadlinePick(this.day, this.kind);

  Map<String, dynamic> toJson() => {'day': day, 'kind': kind.name};

  static HomeHeadlinePick? fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final kind = HomeHeadlineKind.values.where((it) => it.name == json['kind']).firstOrNull;
    if (day is! String || kind == null) return null;
    return HomeHeadlinePick(day, kind);
  }
}

String homeHeadlineDay(DateTime now) {
  final local = now.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return "${local.year}-${two(local.month)}-${two(local.day)}";
}

/// Picks today's headline from [candidates]. Today's earlier pick stays for
/// the rest of the day. On a new day the best candidate wins,
/// skipping yesterday's kind when there is another, so Home shows something
/// new each day. Returns null when there are no candidates; the card then
/// falls back to the 24 hour counter.
({HomeHeadline headline, HomeHeadlinePick pick})? pickHomeHeadline(
  List<HomeHeadline> candidates, {
  required HomeHeadlinePick? previous,
  required String today,
}) {
  if (candidates.isEmpty) return null;
  final sorted = [...candidates]..sort((a, b) => b.score.compareTo(a.score));

  if (previous != null && previous.day == today) {
    final same = sorted.where((it) => it.kind == previous.kind).firstOrNull;
    // Its data may be missing only for now (a failed fetch): show the best
    // other one meanwhile but keep today's pick, so it comes back.
    return (headline: same ?? sorted.first, pick: previous);
  }

  final avoid = previous != null && previous.day != today ? previous.kind : null;
  final chosen = sorted.where((it) => it.kind != avoid).firstOrNull ?? sorted.first;
  return (headline: chosen, pick: HomeHeadlinePick(today, chosen.kind));
}
