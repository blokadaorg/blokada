import 'package:collection/collection.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/plus/domain/bypass/bypass.dart';
import 'package:common/src/features/plus/ui/expandable_info_card.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_item_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class VpnBypassSection extends StatefulWidget {
  const VpnBypassSection({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => VpnBypassSectionState();
}

class VpnBypassSectionState extends State<VpnBypassSection>
    with Logging, Disposables {
  late final _actor = Core.get<BypassActor>();
  late final _apps = Core.get<BypassedAppsValue>();

  final Map<String, Widget> _appIcons = {};

  @override
  void initState() {
    super.initState();
    disposeLater(_apps.onChange.listen(rebuild));
    rebuild(null);
  }

  @override
  rebuild(dynamic it) async {
    if (!mounted) return;
    setState(() {});
    _loadAppIcons(); // Load icons asynchronously
  }

  @override
  void dispose() {
    disposeAll();
    _appIcons.clear();
    super.dispose();
  }

  void _removeBypass(InstalledApp app) async {
    await _actor.setAppBypass(Markers.userTap, app.packageName, false);
    setState(() {});
  }

  _loadAppIcons() async {
    for (var app in _apps.now) {
      if (_appIcons.containsKey(app.packageName)) continue;
      if (!(await _loadAppIcon(app.packageName))) continue;
      setState(() {});
    }
  }

  Future<bool> _loadAppIcon(String packageName) async {
    try {
      final iconBytes = await _actor.getAppIcon(packageName);
      if (iconBytes != null && mounted) {
        _appIcons[packageName] = Image.memory(
          iconBytes,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        );
        return true;
      }
    } catch (e, s) {
      log(Markers.ui)
          .e(msg: "bypass: failed to load app icon: $e", err: e, stack: s);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _buildAppsList(),
    );
  }

  Widget _buildAppsList() {
    return SlidableAutoCloseBehavior(
      child: ListView(
          primary: true,
          children: <Widget>[
                // Padding for header
                SizedBox(height: getTopPadding(context)),
                ExpandableInfoCard(text: "bypass info".i18n),
                const SizedBox(height: 40),
                Text("Bypassed apps",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Up part of the rounded main section
                Container(
                  decoration: BoxDecoration(
                    color: context.theme.bgMiniCard,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12)),
                  ),
                  height: 12,
                ),
              ] +
              // Content
              ((_apps.now.isEmpty) ? _buildEmpty() : _buildItems(context))
              // Down part of the rounded main section
              +
              [
                Container(
                  decoration: BoxDecoration(
                    color: context.theme.bgMiniCard,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12)),
                  ),
                  height: 12,
                ),
              ]),
    );
  }

  List<Widget> _buildEmpty() {
    return [
      Container(
        decoration: BoxDecoration(
          color: context.theme.bgMiniCard,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Text(
              "bypass none".i18n,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: context.theme.textSecondary,
                  ),
            ),
          ),
        ),
      )
    ];
  }

  List<Widget> _buildItems(BuildContext context) {
    return _apps.now.mapIndexed((index, it) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          AppBypassItemSwipe(
            app: it,
            icon: _appIcons[it.packageName],
            onRemove: () => _removeBypass(it),
          ),
          index < _apps.now.length - 1
              ? const CommonDivider(indent: 60)
              : Container(),
        ]),
      );
    }).toList();
  }
}
