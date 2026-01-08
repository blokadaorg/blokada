import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/freemium_screen.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class StatsSection extends StatefulWidget {
  final DeviceTag? deviceTag;
  final bool primary;
  final bool isHeader;
  final bool freemium;

  const StatsSection({
    Key? key,
    required this.deviceTag,
    required this.isHeader,
    this.primary = true,
    this.freemium = true,
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

  final ScrollController _scrollController = ScrollController();
  bool _isReady = false;

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

  Future<void> _loadMore() async {
    if (_journal.isLoadingMore || !_journal.hasMoreData) return;

    print("📊 Fetching more activity entries (current: ${_entries.now.length})");
    await _journal.fetch(Markers.stats, tag: widget.deviceTag, append: true);
    print("📊 Fetch completed (total: ${_entries.now.length})");

    // Trigger rebuild to show new entries and update loading indicator
    if (mounted) {
      setState(() {});
    }
  }

  @override
  rebuild(dynamic it) async {
    if (!mounted) return;
    await _journal.fetch(Markers.stats, tag: widget.deviceTag);
  }

  rebuildEntries(dynamic it) {
    if (!mounted) return;
    setState(() {
      _isReady = true;
    });

    // After rebuilding, check if the list is scrollable
    // If not scrollable and more data available, fetch more
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _pullToRefresh() async {
    // To make it more obvious visually
    _journal.clear();
    setState(() {
      _isReady = false;
    });
    await sleepAsync(const Duration(milliseconds: 200));

    rebuild(null);
    rebuildEntries(null);
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
                      (!_isReady || _entries.now.isEmpty
                          ? _buildEmpty(context)
                          : _buildItems(context)) +
                      (_journal.isLoadingMore
                          ? [_buildLoadingIndicator(context)]
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
        (_isFreemium)
            ? FreemiumScreen(
                title: "freemium stats cta header".i18n,
                subtitle: "freemium stats cta desc".i18n,
                placement: Placement.freemiumActivity,
              )
            : Container(),
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
            CommonClickable(
                onTap: () {
                  showStatsFilterDialog(context, onConfirm: (filter) {
                    _filter.now = filter;
                  });
                },
                child: Text(
                  "universal action search".i18n,
                  style: TextStyle(
                    color: context.theme.accent,
                    fontSize: 17,
                  ),
                )),
          ],
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    return _entries.now.mapIndexed((index, it) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ActivityItem(entry: it),
          index < _entries.now.length - 1 ? const CommonDivider(indent: 60) : Container(),
        ]),
      );
    }).toList();
  }

  List<Widget> _buildEmpty(BuildContext context) {
    return [
      Container(
        color: context.theme.bgMiniCard,
        child: Center(
          child: Text(
            (!_isReady || _journal.allEntries.isEmpty)
                ? "universal status waiting for data".i18n
                : "family search empty".i18n,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      color: context.theme.bgMiniCard,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
