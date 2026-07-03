import 'package:common/src/core/core.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/detail_pane_host.dart';
import 'package:common/src/shared/layout/detail_pane_placeholder.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Fake registry so pane bodies are inspectable Texts instead of real
// sections (which would drag their stores into these layout tests).
class _FakeDetailRoutes extends DetailRoutes {
  @override
  DetailRoute? resolve(Paths path) {
    return DetailRoute(
      path: path,
      title: (_) => "title:${path.name}",
      body: (context, args) => Text("body:${path.name}:${args ?? "-"}"),
      paneBody: (context, args) => Text("pane:${path.name}:${args ?? "-"}"),
      trailing: (context, args) => Text("trailing:${path.name}"),
    );
  }
}

class _FakeHandle implements DetailPaneHandle {
  _FakeHandle({required this.active, required this.paths});

  bool active;
  final Set<Paths> paths;
  final List<Paths> shown = [];

  @override
  bool get isActive => active;

  @override
  bool accepts(Paths path) => paths.contains(path);

  @override
  void show(Paths path, Object? arguments) => shown.add(path);
}

const _theme = BlokadaTheme(
  bgColor: Colors.black,
  bgColorHome1: Colors.black,
  bgColorHome2: Colors.black,
  bgColorHome3: Colors.black,
  bgColorCard: Colors.black,
  panelBackground: Colors.black,
  cloud: Colors.blue,
  accent: Colors.blue,
  freemium: Colors.orange,
  shadow: Colors.black,
  bgMiniCard: Colors.black,
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  divider: Colors.grey,
);

void main() {
  group("DetailPaneHosts", () {
    test("most recently registered active host that accepts the path wins", () {
      final hosts = DetailPaneHosts();
      final older = _FakeHandle(active: true, paths: {Paths.settingsExceptions});
      final newer = _FakeHandle(active: true, paths: {Paths.settingsExceptions});
      hosts.register(older);
      hosts.register(newer);

      expect(hosts.openInPane(Paths.settingsExceptions, null), isTrue);
      expect(newer.shown, [Paths.settingsExceptions]);
      expect(older.shown, isEmpty);
    });

    test("skips inactive hosts and hosts that do not accept the path", () {
      final hosts = DetailPaneHosts();
      final inactive = _FakeHandle(active: false, paths: {Paths.settingsExceptions});
      final wrongPath = _FakeHandle(active: true, paths: {Paths.deviceStats});
      final match = _FakeHandle(active: true, paths: {Paths.settingsExceptions});
      hosts.register(match);
      hosts.register(wrongPath);
      hosts.register(inactive);

      expect(hosts.openInPane(Paths.settingsExceptions, null), isTrue);
      expect(match.shown, [Paths.settingsExceptions]);

      expect(hosts.openInPane(Paths.support, null), isFalse);
    });

    test("unregistered hosts no longer receive paths", () {
      final hosts = DetailPaneHosts();
      final host = _FakeHandle(active: true, paths: {Paths.settingsExceptions});
      hosts.register(host);
      hosts.unregister(host);
      expect(hosts.openInPane(Paths.settingsExceptions, null), isFalse);
    });
  });

  group("WithDetailPane", () {
    setUp(() async {
      await Core.di.reset();
      Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.iOS);
      Core.register<DetailRoutes>(_FakeDetailRoutes());
      Core.register<DetailPaneHosts>(DetailPaneHosts());
    });

    Future<void> setSize(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpHost(
      WidgetTester tester, {
      Paths? initialDetail,
      Object? initialDetailArguments,
      Object? Function(Paths path, Object? arguments)? paneArguments,
      Widget? Function(BuildContext context, Paths? shownDetail)? trailing,
    }) async {
      await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TopBarController(),
        child: MaterialApp(
          theme: ThemeData(extensions: const [_theme]),
          home: WithDetailPane(
            title: "Test",
            screenSemanticsId: AutomationIds.screenSettings,
            master: const Text("master"),
            detailPaths: const {Paths.settingsExceptions, Paths.settingsRetention},
            initialDetail: initialDetail,
            initialDetailArguments: initialDetailArguments,
            paneArguments: paneArguments,
            trailing: trailing,
          ),
        ),
      ),
      );
    }

    Finder screenTitles() => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == AutomationIds.screenTitle);

    testWidgets("expanded shows master, initial detail pane and registry trailing",
      (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(tester, initialDetail: Paths.settingsExceptions);

      expect(find.text("master"), findsOneWidget);
      expect(find.text("pane:settingsExceptions:-"), findsOneWidget);
      expect(find.text("trailing:settingsExceptions"), findsOneWidget);
      expect(screenTitles(), findsOneWidget);
    });

    testWidgets("expanded without initial detail shows the placeholder", (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(tester);

      expect(find.byType(DetailPanePlaceholder), findsOneWidget);
    });

    testWidgets("Navigation.open swaps the pane for accepted paths", (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(tester, initialDetail: Paths.settingsExceptions);
      await Navigation.open(Paths.settingsRetention);
      await tester.pump();

      expect(find.text("pane:settingsRetention:-"), findsOneWidget);
      expect(find.text("pane:settingsExceptions:-"), findsNothing);
      expect(find.text("trailing:settingsRetention"), findsOneWidget);
    });

    testWidgets("compact renders the master alone and refuses pane opens", (tester) async {
      await setSize(tester, const Size(400, 800));

      await pumpHost(tester, initialDetail: Paths.settingsExceptions);

      expect(find.text("master"), findsOneWidget);
      expect(find.text("pane:settingsExceptions:-"), findsNothing);
      expect(
          Core.get<DetailPaneHosts>().openInPane(Paths.settingsExceptions, null), isFalse);
    });

    testWidgets("disposed hosts fall through to a push", (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(tester, initialDetail: Paths.settingsExceptions);
      expect(
          Core.get<DetailPaneHosts>().openInPane(Paths.settingsRetention, null), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(
          Core.get<DetailPaneHosts>().openInPane(Paths.settingsRetention, null), isFalse);
    });

    testWidgets("host trailing overrides the registry and shows in both modes",
        (tester) async {
      await setSize(tester, const Size(1200, 800));
      await pumpHost(
        tester,
        initialDetail: Paths.settingsExceptions,
        trailing: (context, shown) => Text("host-trailing:${shown?.name}"),
      );
      expect(find.text("host-trailing:settingsExceptions"), findsOneWidget);
      expect(find.text("trailing:settingsExceptions"), findsNothing);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      expect(find.text("host-trailing:null"), findsOneWidget);
    });

    testWidgets("pane selection survives a compact resize round-trip", (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(tester, initialDetail: Paths.settingsExceptions);
      await Navigation.open(Paths.settingsRetention);
      await tester.pump();
      expect(find.text("pane:settingsRetention:-"), findsOneWidget);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      expect(find.text("pane:settingsRetention:-"), findsNothing);
      expect(find.text("master"), findsOneWidget);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pump();
      expect(find.text("pane:settingsRetention:-"), findsOneWidget);
    });

    testWidgets("paneArguments hook refreshes arguments per build", (tester) async {
      await setSize(tester, const Size(1200, 800));

      await pumpHost(
        tester,
        initialDetail: Paths.settingsExceptions,
        initialDetailArguments: "stale",
        paneArguments: (path, args) => "fresh",
      );

      expect(find.text("pane:settingsExceptions:fresh"), findsOneWidget);
    });
  });
}
