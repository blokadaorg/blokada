import 'package:common/src/core/core.dart';
import 'package:common/src/features/plan/domain/plan.dart';
import 'package:common/src/features/settings/ui/settings_item.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Short, locale-formatted date for the plan status: "14 Feb" / "Feb 14",
/// with the year only when it is not the current one.
String formatPlanDate(DateTime date, DateTime now, String locale) {
  final local = date.toLocal();
  final withYear = local.year != now.year;
  DateFormat format(String loc) => withYear ? DateFormat.yMMMd(loc) : DateFormat.MMMd(loc);
  // intl throws when it has no date data for the locale (ArgumentError) or
  // none loaded at all (LocaleDataException, not exported); en_US is built in.
  try {
    return format(locale).format(local);
  } on ArgumentError {
    return format("en_US").format(local);
  } on Exception {
    return format("en_US").format(local);
  }
}

/// The plain one-line status: "Blokada Cloud · renews 14 Feb".
String planStatusText(Plan plan, DateTime now, String locale) {
  final date = plan.date;
  final formatted = date == null ? null : formatPlanDate(date, now, locale);
  switch (plan.renewal) {
    case PlanRenewal.renews:
      return "settings plan status renews".i18n.withParams(plan.tierName, formatted!);
    case PlanRenewal.ends:
      return "settings plan status ends".i18n.withParams(plan.tierName, formatted!);
    case PlanRenewal.activeUntil:
      if (formatted == null) return plan.tierName;
      return "settings plan status active until".i18n.withParams(plan.tierName, formatted);
    case PlanRenewal.expired:
      return "notification acc header".i18n;
    case PlanRenewal.none:
      return "account plan none".i18n;
  }
}

/// The plan rows at the top of Settings "Your plan" (#454): status, Cloud →
/// Plus upgrade, manage in the right store, and restore purchases. Every row
/// ends with a divider: the account rows (account ID, Restore Account ID)
/// follow them in the same card.
class PlanRows extends StatefulWidget {
  const PlanRows({super.key});

  @override
  State<PlanRows> createState() => _PlanRowsState();
}

class _PlanRowsState extends State<PlanRows> with Logging, Disposables {
  late final _plan = Core.get<CurrentPlanValue>();
  late final _actor = Core.get<PlanActor>();

  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    disposeLater(_plan.onChange.listen(rebuild));
    _actor.refresh(Markers.ui);
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan.now;
    final status = planStatusText(plan, DateTime.now(), Localizations.localeOf(context).toString());
    final canManage = canManagePlan(plan, Core.act.platform);
    final canUpgrade = plan.isActive && plan.type == AccountType.cloud;

    return Column(
      children: [
        // Explicit label with ExcludeSemantics so VoiceOver reads it once and
        // automation can read the status (same as the account status header).
        Semantics(
          identifier: AutomationIds.settingsPlanStatus,
          label: status,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(CupertinoIcons.creditcard, size: 22, color: context.theme.divider),
                  const SizedBox(width: 10),
                  Expanded(child: Text(status, style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          ),
        ),
        const CommonDivider(),
        if (canUpgrade) ...[
          SettingsItem(
            icon: CupertinoIcons.arrow_up_circle,
            text: "settings plan action upgrade plus".i18n,
            automationId: AutomationIds.settingsPlanUpgrade,
            onTap: () {
              log(Markers.userTap).trace("settingsPlanUpgrade", (m) async {
                await _actor.upgrade(m);
              });
            },
          ),
          const CommonDivider(),
        ],
        if (canManage) ...[
          SettingsItem(
            icon: CupertinoIcons.creditcard,
            text: "account action manage subscription".i18n,
            automationId: AutomationIds.settingsPlanManage,
            onTap: () {
              log(Markers.userTap).trace("settingsPlanManage", (m) async {
                try {
                  await _actor.manage(m);
                } catch (_) {
                  // Logged by the trace. A web plan mints a sign-in link,
                  // which can fail on the network; say so instead of nothing.
                  if (mounted) showErrorDialog(this.context, null);
                  rethrow;
                }
              });
            },
          ),
          const CommonDivider(),
        ],
        if (plan.canRestore) ...[
          SettingsItem(
            icon: CupertinoIcons.arrow_clockwise,
            text: "payment action restore".i18n,
            automationId: AutomationIds.settingsPlanRestore,
            onTap: _restore,
          ),
          const CommonDivider(),
        ],
      ],
    );
  }

  void _restore() {
    if (_restoring) return;
    setState(() => _restoring = true);
    log(Markers.userTap).trace("settingsPlanRestore", (m) async {
      try {
        final outcome = await _actor.restorePurchases(m);
        if (!mounted) return;
        if (outcome == PlanRestoreOutcome.notFound) _showNotFound();
      } finally {
        if (mounted) setState(() => _restoring = false);
      }
    });
  }

  // Same message the paywall shows for a restore with nothing active (#395).
  void _showNotFound() {
    showDefaultDialog(
      context,
      title: Text("payment action restore".i18n),
      content: (context) => Text("error restore not found".i18n),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("universal action close".i18n),
        ),
      ],
    );
  }
}
