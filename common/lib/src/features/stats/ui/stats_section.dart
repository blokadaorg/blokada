import 'dart:async';

import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/features/stats/domain/controller.dart' show StatsController;
import 'package:common/src/features/stats/ui/activity_groups.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/features/stats/ui/stats_error.dart';
import 'package:common/src/features/stats/ui/stats_filter_chips.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class StatsSection extends StatefulWidget {
  final DeviceTag? deviceTag;
  final bool isHeader;

  /// The time the rows are grouped against; tests pass a fixed one.
  final DateTime Function() now;

  const StatsSection({
    Key? key,
    required this.deviceTag,
    required this.isHeader,
    this.now = DateTime.now,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => StatsSectionState();
}

class StatsSectionState extends State<StatsSection> with Disposables {
  late final _journal = Core.get<JournalActor>();
  late final _custom = Core.get<CustomlistActor>();
  late final _filter = Core.get<JournalFilterValue>();
  late final _entries = Core.get<JournalEntriesValue>();
  late final _customlist = Core.get<CustomListsValue>();
  late final _accountStore = Core.get<AccountStore>();
  late final _collecting = Core.get<StatsController>().collecting;

  final ScrollController _scrollController = ScrollController();
  bool _isReady = false;
  // The last load (or the last page) failed; shows an error with a retry.
  bool _failed = false;
  bool _moreFailed = false;
  // A pull to refresh is loading; rows stay on screen, but no page may load,
  // as it would start from the old cursor and mix with the fresh first page.
  bool _refreshing = false;
  // Row keys on screen, and the ones a reload just added, which fade in.
  Set<String> _shownKeys = {};
  Set<String> _freshKeys = {};

  bool get _isFreemium {
    return _accountStore.isFreemium;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    disposeLater(_entries.onChange.listen(rebuildEntries));
    disposeLater(_filter.onChange.listen(rebuild));
    disposeLater(_customlist.onChange.listen(rebuild));
    disposeLater(_collecting.onChange.listen((_) => setState(() {})));
    // Before the first fetch, which then adds the devices in its rows.
    unawaited(_journal.loadDevices(Markers.stats));
    rebuild(null);
    _custom.fetch(Markers.stats);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    disposeAll();
    super.dispose();
  }

  void _onScroll() {
    if (_journal.isLoadingMore || !_journal.hasMoreData || _isFreemium) return;

    // Check if scrolled near bottom (within 200 pixels)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      print("📊 Activity pagination triggered - loading more entries");
      _loadMore();
    }
  }

  /// Next page. A failed page waits for the retry tap ([retry]) rather than
  /// refetching on every scroll, and nothing loads before the first page
  /// arrives: both start from no cursor and would add the same rows twice.
  Future<void> _loadMore({bool retry = false}) async {
    if (!_isReady || _refreshing || _journal.isLoadingMore || !_journal.hasMoreData) return;
    if (_moreFailed && !retry) return;

    print("📊 Fetching more activity entries (current: ${_entries.now.length})");
    _moreFailed = false;
    try {
      final fetch = _journal.fetch(Markers.stats, tag: widget.deviceTag, append: true);
      // Shows the placeholder row while the page loads.
      if (mounted) setState(() {});
      await fetch;
      print("📊 Fetch completed (total: ${_entries.now.length})");
    } catch (_) {
      // The fetch logs it.
      _moreFailed = true;
    }

    // Trigger rebuild to show new entries and update loading indicator
    if (mounted) {
      setState(() {});
    }
  }

  @override
  rebuild(dynamic it) async {
    if (!mounted) return;
    try {
      await _journal.fetch(Markers.stats, tag: widget.deviceTag);
    } catch (_) {
      // The fetch logs it.
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _isReady = false;
    });
    rebuild(null);
  }

  rebuildEntries(dynamic it) {
    if (!mounted) return;
    final keys = _listKeys(_entries.now).toSet();
    // Only rows added to a list already on screen; the first load just shows.
    _freshKeys = _isReady && _shownKeys.isNotEmpty ? keys.difference(_shownKeys) : {};
    _shownKeys = keys;
    setState(() {
      _isReady = true;
      _failed = false;
      _moreFailed = false;
    });

    // After rebuilding, check if the list is scrollable
    // If not scrollable and more data available, fetch more
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Rows built from now on, like ones scrolled into view, just show.
      _freshKeys = {};
      _checkIfNeedsMoreData();
    });
  }

  void _checkIfNeedsMoreData() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_journal.isLoadingMore || !_journal.hasMoreData || _isFreemium) return;

    // Check if the content is shorter than the viewport (not scrollable)
    final isScrollable = _scrollController.position.maxScrollExtent > 0;

    if (!isScrollable && _entries.now.isNotEmpty) {
      print("📊 Activity list not scrollable but has more data - auto-loading next page");
      _loadMore();
    }
  }

  /// Reloads in place: the current rows stay while the indicator spins, and
  /// rows that weren't there before fade in. A failure shows the error.
  Future<void> _pullToRefresh() async {
    unawaited(Haptics.light());
    setState(() {
      _failed = false;
      _moreFailed = false;
    });
    _refreshing = true;
    // Also retries a device list that failed when the screen opened.
    unawaited(_journal.loadDevices(Markers.stats));
    try {
      await rebuild(null);
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isFreemium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: RefreshIndicator(
              displacement: 100.0,
              onRefresh: _pullToRefresh,
              child: ListView(
                  controller: _scrollController,
                  primary: false, // Must be false when providing a custom controller
                  children: [
                        // Header for v6 or padding for Family
                        (widget.isHeader)
                            ? _buildHeaderForV6(context)
                            : SizedBox(height: getTopPadding(context)),
                        const StatsFilterChips(),
                        // The rest of the screen
                        Container(
                          decoration: BoxDecoration(
                            color: context.theme.bgMiniCard,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                          ),
                          height: 12,
                        ),
                      ] +
                      (_failed
                          ? [_buildError(context, _retry)]
                          : !_isReady
                              ? [_buildLoading(context, rows: 8, header: true)]
                              : _entries.now.isEmpty
                                  ? _buildEmpty(context)
                                  : _buildItems(context)) +
                      (_failed || !_isReady
                          ? []
                          : _journal.isLoadingMore
                              ? [_buildLoading(context, rows: 2)]
                              : _moreFailed
                                  ? [_buildError(context, () => _loadMore(retry: true))]
                                  : []) +
                      [
                        Container(
                          decoration: BoxDecoration(
                            color: context.theme.bgMiniCard,
                            borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                          ),
                          height: 12,
                        ),
                      ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderForV6(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "main tab activity".i18n,
              style: const TextStyle(
                fontSize: 34.0, // Mimic large iOS-style header
                fontWeight: FontWeight.bold,
              ),
            ),
            const StatsFilterAction(),
          ],
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  /// Keys rows by domain and time, so a reload keeps the rows it already
  /// shows. A repeat gets a count, since keys must be unique.
  static List<String> _rowKeys(List<UiJournalEntry> entries) {
    final seen = <String, int>{};
    return entries.map((it) {
      final key = "${it.domainName}|${it.timestamp.toIso8601String()}";
      final count = seen[key] = (seen[key] ?? 0) + 1;
      return count == 1 ? key : "$key#$count";
    }).toList();
  }

  /// The time group header of each entry, worked out again on every build,
  /// so rows loaded later, and time passing, land in the right group.
  List<String> _groupLabels(List<UiJournalEntry> entries) {
    final now = widget.now();
    final locale = Localizations.maybeLocaleOf(context)?.toString() ?? "en_US";
    return activityGroupLabels(entries.map((it) => it.timestamp), now, locale);
  }

  /// Keys of the group headers, one per header shown, in list order.
  static List<String?> _headerKeys(List<String> labels) {
    final seen = <String, int>{};
    return labels.mapIndexed((index, label) {
      if (index > 0 && labels[index - 1] == label) return null;
      final count = seen[label] = (seen[label] ?? 0) + 1;
      return count == 1 ? "group|$label" : "group|$label#$count";
    }).toList();
  }

  /// Every row and header key, for telling which ones a reload added.
  List<String> _listKeys(List<UiJournalEntry> entries) {
    return [..._rowKeys(entries), ..._headerKeys(_groupLabels(entries)).whereNotNull()];
  }

  List<Widget> _buildItems(BuildContext context) {
    final entries = _entries.now;
    final keys = _rowKeys(entries);
    final labels = _groupLabels(entries);
    final headerKeys = _headerKeys(labels);
    final items = <Widget>[];
    for (var index = 0; index < entries.length; index++) {
      final headerKey = headerKeys[index];
      if (headerKey != null) {
        items.add(
          _FadeIn(
            key: ValueKey(headerKey),
            animate: _freshKeys.contains(headerKey),
            child: Container(
              color: context.theme.bgMiniCard,
              child: _GroupHeader(label: labels[index], first: index == 0),
            ),
          ),
        );
      }
      // No divider before the next group's header, or after the last row.
      final lastInGroup = index == entries.length - 1 || headerKeys[index + 1] != null;
      items.add(
        _FadeIn(
          key: ValueKey(keys[index]),
          animate: _freshKeys.contains(keys[index]),
          child: Container(
            color: context.theme.bgMiniCard,
            child: Column(
              children: [
                ActivityItem(entry: entries[index]),
                if (!lastInGroup) const CommonDivider(indent: 12),
              ],
            ),
          ),
        ),
      );
    }
    return items;
  }

  List<Widget> _buildEmpty(BuildContext context) {
    return [
      Container(
        color: context.theme.bgMiniCard,
        child: Center(
          child: Text(
            _journal.allEntries.isNotEmpty
                ? "family search empty".i18n
                : _collecting.now
                ? "activity logging collecting".i18n
                : "universal status waiting for data".i18n,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
  }

  // Shaped like [ActivityItem] rows, with room for the first group
  // [header], so nothing moves when the entries arrive.
  Widget _buildLoading(BuildContext context, {required int rows, bool header = false}) {
    return Container(
      color: context.theme.bgMiniCard,
      child: Column(
        children: [
          // An unseen header, so the room matches at any text size.
          if (header)
            ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: _GroupHeader(label: "activity group just now".i18n, first: true),
              ),
            ),
          LoadingPlaceholder.rows(
            count: rows,
            rowHeight: ActivityItem.rowHeight,
            dividerIndent: 12,
            padding: const EdgeInsets.only(left: 12, right: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Container(
      color: context.theme.bgMiniCard,
      child: StatsError(onRetry: onRetry),
    );
  }
}

/// Names the time group of the rows below it, e.g. "Yesterday". Marked as a
/// header, so screen readers can jump from group to group.
class _GroupHeader extends StatelessWidget {
  final String label;
  final bool first;

  const _GroupHeader({required this.label, required this.first});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        // The first sits right under the card's top edge; later ones keep
        // a gap from the group above.
        padding: EdgeInsets.only(left: 12, right: 12, top: first ? 4 : 16, bottom: 6),
        child: Text(
          label,
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Fades a row in when [animate] is set as it first appears; otherwise
/// shows it as is.
class _FadeIn extends StatefulWidget {
  final bool animate;
  final Widget child;

  const _FadeIn({super.key, required this.animate, required this.child});

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.animate ? 0.0 : 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}
