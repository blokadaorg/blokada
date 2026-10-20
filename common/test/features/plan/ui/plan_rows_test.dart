import 'package:common/src/core/core.dart';
import 'package:common/src/features/plan/domain/plan.dart';
import 'package:common/src/features/plan/ui/plan_rows.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobx/mobx.dart';

import '../../../golden/golden_tools.dart';

final _now = DateTime(2026, 10, 20);

Plan _plan(PlanRenewal renewal, {DateTime? date, AccountType type = AccountType.cloud}) =>
    Plan(type: type, renewal: renewal, date: date, store: PlanStore.appStore);

Future<void> _pump(WidgetTester tester, {required String? type, String? source}) async {
  await bootModules(tester);
  final json = JsonAccount(
    id: 'testaccount01',
    activeUntil: '2099-01-01T00:00:00Z',
    active: type != null,
    type: type,
  );
  json.paymentSource = source;
  runInAction(() => Core.get<AccountStore>().account = AccountState('testaccount01', json));
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: const Scaffold(body: SingleChildScrollView(child: PlanRows())),
    ),
  );
  // The store read fails without a platform; let the fallback settle.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}

Finder _byId(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

void main() {
  // The app gets date data from GlobalMaterialLocalizations; plain tests load it.
  setUpAll(() => initializeDateFormatting());

  group('planStatusText', () {
    test('renews, ends and active until carry the plan name and a short date', () {
      final date = DateTime(2027, 2, 14);
      expect(
        planStatusText(_plan(PlanRenewal.renews, date: date), _now, 'en_GB'),
        "settings plan status renews".i18n.withParams("Blokada Cloud", "14 Feb 2027"),
      );
      expect(
        planStatusText(_plan(PlanRenewal.ends, date: date), _now, 'en_US'),
        "settings plan status ends".i18n.withParams("Blokada Cloud", "Feb 14, 2027"),
      );
      expect(
        planStatusText(
          _plan(PlanRenewal.activeUntil, date: date, type: AccountType.plus),
          _now,
          'en_US',
        ),
        "settings plan status active until".i18n.withParams("Blokada Plus", "Feb 14, 2027"),
      );
    });

    test('active until without a date shows just the plan name', () {
      expect(planStatusText(_plan(PlanRenewal.activeUntil), _now, 'en'), "Blokada Cloud");
    });

    test('expired and no plan', () {
      expect(
        planStatusText(_plan(PlanRenewal.expired), _now, 'en'),
        "notification acc header".i18n,
      );
      expect(planStatusText(Plan.empty, _now, 'en'), "account plan none".i18n);
    });
  });

  group('formatPlanDate', () {
    test('drops the year within the current year, follows the locale', () {
      expect(formatPlanDate(DateTime(2026, 11, 3), _now, 'en_US'), "Nov 3");
      expect(formatPlanDate(DateTime(2026, 11, 3), _now, 'en_GB'), "3 Nov");
      expect(formatPlanDate(DateTime(2027, 2, 14), _now, 'en_US'), "Feb 14, 2027");
    });

    test('an unknown locale falls back to English', () {
      expect(formatPlanDate(DateTime(2026, 11, 3), _now, 'xx_YY'), "Nov 3");
    });
  });

  group('PlanRows', () {
    testWidgets('a Cloud plan from the App Store can upgrade, manage and restore', (tester) async {
      await _pump(tester, type: 'cloud', source: 'apple');

      expect(
        find.text(
          "settings plan status active until".i18n.withParams("Blokada Cloud", "Jan 1, 2099"),
        ),
        findsOneWidget,
      );
      expect(_byId(AutomationIds.settingsPlanUpgrade), findsOneWidget);
      expect(_byId(AutomationIds.settingsPlanManage), findsOneWidget);
      expect(_byId(AutomationIds.settingsPlanRestore), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Plus has no upgrade; a ticket source has nothing to manage', (tester) async {
      await _pump(tester, type: 'plus', source: 'ticket');

      expect(_byId(AutomationIds.settingsPlanUpgrade), findsNothing);
      expect(_byId(AutomationIds.settingsPlanManage), findsNothing);
      expect(_byId(AutomationIds.settingsPlanRestore), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('no plan still offers restore purchases', (tester) async {
      await _pump(tester, type: null);

      expect(find.text("account plan none".i18n), findsOneWidget);
      expect(_byId(AutomationIds.settingsPlanUpgrade), findsNothing);
      expect(_byId(AutomationIds.settingsPlanManage), findsNothing);
      expect(_byId(AutomationIds.settingsPlanRestore), findsOneWidget);

      await _unmount(tester);
    });
  });
}
