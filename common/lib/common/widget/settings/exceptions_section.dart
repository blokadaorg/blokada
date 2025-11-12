import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/settings/exception_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ExceptionsSection extends StatefulWidget {
  final bool primary;

  const ExceptionsSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionsSectionState();
}

enum ExceptionsTab { blocked, allowed }

class ExceptionsSectionState extends State<ExceptionsSection> with Logging, Disposables {
  late final _custom = Core.get<CustomlistActor>();
  late final _lists = Core.get<CustomListsValue>();

  bool _isLoading = true;
  List<CustomListEntry> _allowed = [];
  List<CustomListEntry> _denied = [];
  ExceptionsTab _selectedTab = ExceptionsTab.blocked;

  @override
  void initState() {
    super.initState();
    disposeLater(_lists.onChange.listen((_) => _reload(fetch: false)));
    _reload();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  _reload({bool fetch = true}) async {
    if (!mounted) return;
    if (fetch) {
      setState(() {
        _isLoading = true;
      });
    }
    await log(Markers.ui).trace("fetchCustom", (m) async {
      if (fetch) await _custom.fetch(m);
      if (!mounted) return;
      setState(() {
        _allowed = _lists.now.allowed;
        _denied = _lists.now.denied;
        _sort();
        _isLoading = false;
      });
    });
  }

  _sort() {
    _allowed.sort((a, b) => a.domainName.compareTo(b.domainName));
    _denied.sort((a, b) => a.domainName.compareTo(b.domainName));
  }

  @override
  Widget build(BuildContext context) {
    final currentEntries = _selectedTab == ExceptionsTab.blocked ? _denied : _allowed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SlidableAutoCloseBehavior(
        child: ListView(
          primary: widget.primary,
          children: [
            SizedBox(height: getTopPadding(context)),
            const SizedBox(height: 16),
            CommonCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CupertinoSlidingSegmentedControl<ExceptionsTab>(
                      groupValue: _selectedTab,
                      onValueChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedTab = value;
                          });
                        }
                      },
                      children: {
                        ExceptionsTab.blocked: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.xmark_shield_fill,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "privacy pulse tab blocked".i18n,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ExceptionsTab.allowed: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_shield_fill,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "privacy pulse tab allowed".i18n,
                                style: const TextStyle(
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
                  const CommonDivider(),
                  if (_isLoading && currentEntries.isEmpty)
                    _buildLoadingState()
                  else if (currentEntries.isEmpty)
                    _buildEmptyState(context)
                  else
                    for (int i = 0; i < currentEntries.length; i++) ...[
                      ExceptionItem(
                        entry: currentEntries[i].domainName,
                        wildcard: currentEntries[i].wildcard,
                        blocked: _selectedTab == ExceptionsTab.blocked,
                        onRemove: (_) => _onRemove(currentEntries[i]),
                        onTap: () => _openDomainDetails(
                          currentEntries[i],
                          blocked: _selectedTab == ExceptionsTab.blocked,
                        ),
                      ),
                      if (i < currentEntries.length - 1) const CommonDivider(),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isBlocked = _selectedTab == ExceptionsTab.blocked;
    final message = "privacy pulse empty".i18n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: context.theme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  _onRemove(CustomListEntry entry) async {
    log(Markers.userTap).trace("deleteCustom", (m) async {
      await _custom.remove(m, entry.domainName, entry.wildcard);
    });
  }

  void _openDomainDetails(CustomListEntry entry, {required bool blocked}) {
    final domain = entry.domainName;
    final mainEntry = UiJournalMainEntry(
      domainName: domain,
      requests: 0,
      action: blocked ? UiJournalAction.block : UiJournalAction.allow,
      listId: null,
    );

    Navigation.open(Paths.deviceStatsDetail, arguments: {
      'mainEntry': mainEntry,
      'level': 2,
      'domain': domain,
    });
  }
}
