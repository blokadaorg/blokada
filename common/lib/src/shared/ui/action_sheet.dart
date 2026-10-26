import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The pause menu: an action sheet on iOS, a bottom sheet elsewhere. Both
/// carry the same options and automation ids.
void showPauseActionSheet(BuildContext context,
    {required Function(Duration?) onSelected}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    _showCupertinoSheet(context, onSelected: onSelected);
  } else {
    _showMaterialSheet(context, onSelected: onSelected);
  }
}

void _showCupertinoSheet(BuildContext context,
    {required Function(Duration?) onSelected}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext context) => Semantics(
      identifier: AutomationIds.powerActionSheet,
      container: true,
      child: CupertinoActionSheet(
        title: Text("home power pause status active".i18n),
        // Pause is one flag per account in v6: say so before the user picks,
        // or other phones on the account seem to switch off by themselves (#455).
        message: Text("home power pause scope".i18n),
        // The identifier must wrap the whole tappable action (merged into one
        // node) to surface as an iOS accessibilityIdentifier; on the inner
        // Text child alone it stays on a non-hittable node and Appium cannot
        // resolve it (same root cause fixed for SettingsItem/filter_option).
        // Semantics/MergeSemantics are zero-layout so the sheet is unchanged.
        actions: <Widget>[
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionPauseFive,
              button: true,
              child: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () {
                  onSelected(const Duration(minutes: 5));
                  Navigator.pop(context);
                },
                child: Text("home power action pause five".i18n,
                    style: TextStyle(color: context.theme.cloud)),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionTurnOff,
              button: true,
              child: CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  onSelected(null);
                  Navigator.pop(context);
                },
                child: Text("home power action off all".i18n),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.powerActionCancel,
              button: true,
              child: CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("universal action cancel".i18n,
                    style: TextStyle(color: context.theme.cloud)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMaterialSheet(BuildContext context,
    {required Function(Duration?) onSelected}) {
  // On the root navigator, like the iOS sheet, so it covers the tab bar.
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.theme.bgColorCard,
    builder: (BuildContext context) {
      final error = Theme.of(context).colorScheme.error;
      return Semantics(
        identifier: AutomationIds.powerActionSheet,
        container: true,
        child: SafeArea(
          // Scrolls when the sheet's capped height (landscape, large text)
          // can't fit all three actions.
          child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("home power pause status active".i18n,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      // Pause is one flag per account in v6 (#455).
                      Text("home power pause scope".i18n,
                          style: TextStyle(color: context.theme.textSecondary)),
                    ],
                  ),
                ),
                _MaterialAction(
                  identifier: AutomationIds.powerActionPauseFive,
                  icon: Icons.pause_circle_outline,
                  text: "home power action pause five".i18n,
                  onTap: () {
                    onSelected(const Duration(minutes: 5));
                    Navigator.pop(context);
                  },
                ),
                _MaterialAction(
                  identifier: AutomationIds.powerActionTurnOff,
                  icon: Icons.power_settings_new,
                  text: "home power action off all".i18n,
                  color: error,
                  onTap: () {
                    onSelected(null);
                    Navigator.pop(context);
                  },
                ),
                _MaterialAction(
                  identifier: AutomationIds.powerActionCancel,
                  icon: Icons.close,
                  text: "universal action cancel".i18n,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// One row of the bottom sheet, merged into a single button node so the
/// identifier reaches the accessibility tree.
class _MaterialAction extends StatelessWidget {
  final String identifier;
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback onTap;

  const _MaterialAction({
    required this.identifier,
    required this.icon,
    required this.text,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.theme.textPrimary;
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        button: true,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(icon, color: color),
          title: Text(text, style: TextStyle(color: color)),
          onTap: onTap,
        ),
      ),
    );
  }
}
