import 'package:common/src/shared/ui/blokada_segmented_control.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/crossfade.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/stats_error.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

export 'package:common/src/features/stats/domain/controller.dart' show ToplistRange;

/// Privacy Pulse's top blocked and allowed domains. Draws the toplists
/// section of [StatsController]; it fetches nothing itself.
class TopDomains extends StatefulWidget {
  final Key? headerKey;
  final WeeklyReportToplistHighlight? highlight;
  final ToplistRange range;
  final StatsSection<PulseToplists> section;
  final VoidCallback onRetry;
  const TopDomains({
    super.key,
    this.headerKey,
    this.highlight,
    required this.range,
    required this.section,
    required this.onRetry,
  });

  @override
  State<StatefulWidget> createState() => TopDomainsState();
}

enum ToplistTab { blocked, allowed }

class TopDomainsState extends State<TopDomains> {
  ToplistTab _selectedTab = ToplistTab.blocked;

  @override
  void initState() {
    super.initState();
    _syncSelectedTab();
  }

  @override
  void didUpdateWidget(covariant TopDomains oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      _syncSelectedTab();
    }
  }

  void _syncSelectedTab() {
    final highlight = widget.highlight;
    if (highlight == null) return;
    setState(() {
      _selectedTab = highlight.blocked ? ToplistTab.blocked : ToplistTab.allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlight = widget.highlight;
    final highlightName = highlight?.name.toLowerCase();
    final highlightBlocked = highlight?.blocked;
    final isWeeklyMode = widget.range == ToplistRange.weekly;

    return Builder(
      builder: (context) {
        final data = widget.section.data;
        final isError = widget.section.isError;
        final isLoading = !isError && data == null;
        final currentDomains =
            (_selectedTab == ToplistTab.blocked ? data?.blocked : data?.allowed) ?? const [];
        final deltas =
            _selectedTab == ToplistTab.blocked ? data?.blockedDeltas : data?.allowedDeltas;
        final highlightVisible = highlight != null &&
            isWeeklyMode &&
            !isLoading &&
            highlightBlocked == (_selectedTab == ToplistTab.blocked);
        String _normalized(UiToplistEntry e) =>
            (e.company ?? e.tld ?? '').toLowerCase();
        // Highlight the row whose domain detail is open in the pane — only
        // for selections that originated from a toplist row (Map arguments);
        // a recent-activity selection must not light up a same-named domain
        // here.
        final selectionArguments = PaneSelection.of(context)?.arguments;
        final selectedDomain = selectionArguments is Map
            ? domainOfDetailArguments(selectionArguments)?.toLowerCase()
            : null;
        final deltaMap = <String, ToplistDelta>{};
        if (deltas != null) {
          for (final d in deltas) {
            if (d.type == ToplistDeltaType.same) continue;
            deltaMap[d.name.toLowerCase()] = d;
          }
        }
        // Bars are sized against the top entry.
        final topValue = currentDomains.fold<int>(0, (top, e) => e.value > top ? e.value : top);
        final limitedDeltas = <String, ToplistDelta>{};
        for (final entry in currentDomains) {
          if (limitedDeltas.length >= 3) break;
          final d = deltaMap[_normalized(entry)];
          if (d != null) {
            limitedDeltas[_normalized(entry)] = d;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                key: widget.headerKey,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "privacy pulse toplists header".i18n,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.theme.textPrimary,
                    ),
                  ),
                  Text(
                    widget.range == ToplistRange.daily
                        ? "stats range 24h".i18n
                        : "stats range 7d".i18n,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Combined card with segmented control and list
            CommonCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Segmented control inside card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: BlokadaSegmentedControl<ToplistTab>(
                        groupValue: _selectedTab,
                        onValueChanged: (ToplistTab? value) {
                          if (value != null) {
                            setState(() => _selectedTab = value);
                          }
                        },
                        children: {
                          ToplistTab.blocked: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.xmark_shield_fill,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "privacy pulse tab blocked".i18n,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ToplistTab.allowed: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_shield_fill,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "privacy pulse tab allowed".i18n,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        },
                      ),
                    ),
                  ),

                  const CommonDivider(),

                  // Domain list, loading state, or empty state
                  Crossfade(
                    switchKey: (_selectedTab, widget.range),
                    child: Column(
                      children: [
                        if (isError)
                          StatsError(onRetry: widget.onRetry)
                        else if (isLoading)
                          _buildLoadingState()
                        else if (currentDomains.isEmpty)
                          _buildEmptyState()
                        else
                          for (int i = 0; i < currentDomains.length; i++) ...{
                            _buildDomainItem(
                              currentDomains[i],
                              share: topValue > 0 ? currentDomains[i].value / topValue : 0,
                              delta: limitedDeltas[_normalized(currentDomains[i])],
                              isHighlighted: highlightVisible &&
                                  _normalized(currentDomains[i]) == highlightName,
                              isSelected: selectedDomain != null &&
                                  _normalized(currentDomains[i]) == selectedDomain,
                            ),
                            if (i < currentDomains.length - 1) const CommonDivider(),
                          },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Shaped like the domain rows below, so the card keeps its height.
  Widget _buildLoadingState() {
    return LoadingPlaceholder.rows(
      count: 5,
      rowHeight: 64,
      subtitle: false,
      dividerIndent: 44,
      padding: const EdgeInsets.only(left: 38, right: 24),
    );
  }

  Widget _buildDomainItem(UiToplistEntry entry,
      {required double share,
      ToplistDelta? delta,
      bool isHighlighted = false,
      bool isSelected = false}) {
    final domainName = entry.company ?? entry.tld ?? "Unknown";

    // Selection tint wraps the clickable so it covers the full row
    // (including the tap padding), square, in the shared accent-derived
    // selection color — the unified list-selection style.
    return Container(
      color: isSelected ? context.theme.selection : null,
      child: CommonClickable(
      tapBorderRadius: BorderRadius.zero,
      onTap: () {
        // Convert toplist entry to UiJournalMainEntry for navigation
        final mainEntry = UiJournalMainEntry(
          domainName: domainName,
          requests: entry.value,
          action: entry.blocked ? UiJournalAction.block : UiJournalAction.allow,
          listId: null,
        );

        Navigation.open(Paths.deviceStatsDetail, arguments: {
          'mainEntry': mainEntry,
          'level': 2, // Fetch level 2 (subdomains under this eTLD+1)
          'domain': domainName, // Domain to fetch subdomains for
          'range': widget.range == ToplistRange.weekly ? "7d" : "24h",
        });
      },
      // Matches the pre-refactor box: the clickable's default 12pt plus the
      // old inner paddings (4+6 vertical, 12 trailing).
      padding: const EdgeInsets.only(left: 12, right: 24, top: 22, bottom: 22),
      // The bar sits in the row's bottom padding, so rows keep their height.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            // From the domain name to the count: past the 26pt delta slot,
            // and short of the 24pt chevron.
            left: 26,
            right: 24,
            bottom: -12,
            child: _ShareBar(
              share: share,
              color: entry.blocked ? context.theme.textBlocked : context.theme.textAllowed,
            ),
          ),
          Row(
            children: [
              if (delta != null && delta.type != ToplistDeltaType.same) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(
                    child: Icon(
                      _iconForDelta(delta),
                      color: _colorForDelta(delta, context),
                      size: delta?.type == ToplistDeltaType.newEntry ? 9 : 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const SizedBox(width: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        middleEllipsis(
                          domainName,
                          maxLength:
                              delta != null && delta.type == ToplistDeltaType.newEntry ? 18 : 24,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: context.theme.textPrimary,
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    if (delta != null && delta.type == ToplistDeltaType.newEntry) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          "stats label new".i18n.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.theme.cloud,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                entry.value.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.theme.textSecondary,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                color: context.theme.textSecondary,
                size: 16,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  IconData _iconForDelta(ToplistDelta delta) {
    switch (delta.type) {
      case ToplistDeltaType.up:
        return CupertinoIcons.arrowtriangle_up_fill;
      case ToplistDeltaType.down:
        return CupertinoIcons.arrowtriangle_down_fill;
      case ToplistDeltaType.newEntry:
        return CupertinoIcons.circle_fill;
      case ToplistDeltaType.same:
      default:
        return CupertinoIcons.minus;
    }
  }

  Color _colorForDelta(ToplistDelta delta, BuildContext context) {
    switch (delta.type) {
      case ToplistDeltaType.up:
        return context.theme.cloud;
      case ToplistDeltaType.down:
        return context.theme.cloud;
      case ToplistDeltaType.newEntry:
        return context.theme.cloud;
      case ToplistDeltaType.same:
      default:
        return context.theme.textSecondary;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          "privacy pulse empty".i18n,
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// A thin bar under a toplist row, as wide as the row's [share] of the top
/// entry, so the counts compare at a glance. Grows in when the list appears
/// (a new range or tab); with Reduce Motion it is drawn at its width.
class _ShareBar extends StatelessWidget {
  static const duration = Duration(milliseconds: 600);

  final double share;
  final Color color;

  const _ShareBar({required this.share, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget bar(double factor) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: factor.clamp(0.0, 1.0),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );

    if (Motion.reduced(context)) return bar(share);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: share),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => bar(value),
    );
  }
}
