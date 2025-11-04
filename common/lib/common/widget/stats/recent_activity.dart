import 'dart:async';

import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<StatefulWidget> createState() => RecentActivityState();
}

enum ActivityTab { blocked, allowed }

class RecentActivityState extends State<RecentActivity>
    with Logging, AutomaticKeepAliveClientMixin {
  ActivityTab _selectedTab = ActivityTab.blocked;
  late final _journal = Core.get<JournalActor>();
  late final _deviceStore = Core.get<DeviceStore>();
  late final _journalEntries = Core.get<JournalEntriesValue>();

  final List<UiJournalEntry> _blockedEntries = [];
  final List<UiJournalEntry> _allowedEntries = [];
  bool _isLoading = false;
  int _fetchGeneration = 0;
  String? _lastDeviceAlias;
  mobx.ReactionDisposer? _deviceReaction;
  StreamSubscription? _entriesSubscription;
  bool _pendingRefresh = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _deviceReaction = mobx.autorun((_) {
      final alias = _deviceStore.deviceAlias;
      if (alias.isEmpty) {
        _lastDeviceAlias = null;
        return;
      }
      if (_lastDeviceAlias == alias) return;
      _lastDeviceAlias = alias;
      _fetchEntries(alias);
    });

    _entriesSubscription = _journalEntries.onChange.listen((_) {
      final alias = _deviceStore.deviceAlias;
      if (alias.isEmpty) return;
      if (_isLoading && alias == _lastDeviceAlias) {
        _pendingRefresh = true;
        return;
      }
      _fetchEntries(alias);
    });
  }

  @override
  void dispose() {
    _deviceReaction?.call();
    _entriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentEntries =
        _selectedTab == ActivityTab.blocked ? _blockedEntries : _allowedEntries;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title header with Show All link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Activity",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.theme.textPrimary,
                    ),
                  ),
                  CommonClickable(
                    onTap: () {
                      Navigation.open(Paths.activity);
                    },
                    child: Text(
                      "Show All",
                      style: TextStyle(
                        fontSize: 16,
                        color: context.theme.accent,
                      ),
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
                      child: CupertinoSlidingSegmentedControl<ActivityTab>(
                        groupValue: _selectedTab,
                        onValueChanged: (ActivityTab? value) {
                          if (value != null) {
                            setState(() => _selectedTab = value);
                          }
                        },
                        children: {
                          ActivityTab.blocked: Padding(
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
                                  "Blocked",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ActivityTab.allowed: Padding(
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
                                  "Allowed",
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

                  // Activity list or empty state
                  if (_isLoading && currentEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (currentEntries.isEmpty)
                    _buildEmptyState()
                  else
                    for (int i = 0; i < currentEntries.length; i++) ...{
                      _buildActivityItem(currentEntries[i]),
                      if (i < currentEntries.length - 1) const CommonDivider(),
                    },
                ],
              ),
            ),
          ],
        );
  }

  Widget _buildActivityItem(UiJournalEntry entry) {
    return CommonClickable(
      onTap: () {
        Navigation.open(Paths.deviceStatsDetail, arguments: entry);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    middleEllipsis(entry.domainName, maxLength: 32),
                    style: TextStyle(
                      fontSize: 16,
                      color: context.theme.textPrimary,
                    ),
                    overflow: TextOverflow.clip,
                  ),
                  Text(
                    entry.timestampText,
                    style: TextStyle(
                      color: context.theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: context.theme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          _selectedTab == ActivityTab.blocked ? "No blocked activity" : "No allowed activity",
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchEntries(String deviceName) async {
    final token = ++_fetchGeneration;
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _journal.fetchPreview(
          Markers.stats,
          action: UiJournalAction.block,
          deviceName: deviceName,
          limit: 5,
        ),
        _journal.fetchPreview(
          Markers.stats,
          action: UiJournalAction.allow,
          deviceName: deviceName,
          limit: 5,
        ),
      ]);

      if (!mounted || token != _fetchGeneration) return;

      setState(() {
        _blockedEntries
          ..clear()
          ..addAll(results[0]);
        _allowedEntries
          ..clear()
          ..addAll(results[1]);
        _isLoading = false;
      });
      if (_pendingRefresh) {
        _pendingRefresh = false;
        final alias = _lastDeviceAlias;
        if (alias != null && alias.isNotEmpty) {
          _fetchEntries(alias);
        }
      }
    } catch (e, s) {
      log(Markers.stats).e(msg: "Failed to fetch recent activity preview", err: e, stack: s);
      if (!mounted || token != _fetchGeneration) return;
      setState(() {
        _blockedEntries.clear();
        _allowedEntries.clear();
        _isLoading = false;
      });
      if (_pendingRefresh) {
        _pendingRefresh = false;
        final alias = _lastDeviceAlias;
        if (alias != null && alias.isNotEmpty) {
          _fetchEntries(alias);
        }
      }
    }
  }
}
