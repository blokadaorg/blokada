import 'dart:async';

import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/haptics.dart';
import 'package:common/src/features/stats/domain/controller.dart' show StatsController;
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

  const StatsSection({
    Key? key,
    required this.deviceTag,
    required this.isHeader,
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
    final keys = _rowKeys(_entries.now).toSet();
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
                              ? [_buildLoading(context, rows: 8)]
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

  List<Widget> _buildItems(BuildContext context) {
    final keys = _rowKeys(_entries.now);
    return _entries.now.mapIndexed((index, it) {
      return _FadeIn(
        key: ValueKey(keys[index]),
        animate: _freshKeys.contains(keys[index]),
        child: Container(
          color: context.theme.bgMiniCard,
          child: Column(children: [
            ActivityItem(entry: it),
            index < _entries.now.length - 1 ? const CommonDivider(indent: 60) : Container(),
          ]),
        ),
      );
    }).toList();
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

  // Shaped like [ActivityItem] rows.
  Widget _buildLoading(BuildContext context, {required int rows}) {
    return Container(
      color: context.theme.bgMiniCard,
      child: LoadingPlaceholder.rows(
        count: rows,
        rowHeight: 76,
        leading: 52,
        dividerIndent: 60,
        padding: const EdgeInsets.only(left: 12, right: 14),
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
