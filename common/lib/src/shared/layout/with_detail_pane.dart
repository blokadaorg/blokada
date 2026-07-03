import 'package:common/src/core/core.dart';
import 'package:common/src/shared/layout/detail_pane_host.dart';
import 'package:common/src/shared/layout/detail_pane_placeholder.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:flutter/material.dart';

/// Adaptive master-detail scaffold, the WithTopBar of two-pane screens.
///
/// Exists so top-level screens stop hand-rolling their own
/// `if (isTablet) Row(...)` branches with per-screen `_buildForPath`
/// switches and a shared mutable callback. Compact/medium windows render
/// the master alone (detail paths push full-screen routes, as on phone);
/// expanded windows render master | detail and register this State with
/// DetailPaneHosts so `Navigation.open` lands in the pane. Layout is
/// decided per build from the window size, so Split View / Slide Over /
/// macOS resizing re-layouts live and the pane selection survives the
/// mode flips.
class WithDetailPane extends StatefulWidget {
  final String title;

  /// AutomationIds.screen* marker wrapping both layouts; null for screens
  /// that never had one (family DeviceScreen).
  final String? screenSemanticsId;

  final Widget master;

  /// Which paths render in this host's pane (host-scoped replacement for
  /// the global Paths.openInTablet flag). Anything else pushes normally.
  final Set<Paths> detailPaths;

  /// Pane content before the user selects anything; null shows
  /// [placeholder] instead.
  final Paths? initialDetail;
  final Object? initialDetailArguments;

  final Widget? placeholder;

  /// Lets the host refresh pane arguments on rebuild instead of reusing
  /// the tap-time snapshot — e.g. DeviceScreen re-resolves its
  /// FamilyDevice so a profile change re-renders the filters pane with
  /// current data, matching the old per-screen builders which read fresh
  /// state every build.
  final Object? Function(Paths path, Object? arguments)? paneArguments;

  /// Host-level top-bar action shown in both layout modes (e.g. Activity's
  /// journal search, which belongs to the master list). When provided it
  /// replaces the default of the shown detail route's registry trailing;
  /// receives the shown detail path (null in single-pane mode or with no
  /// selection).
  final Widget? Function(BuildContext context, Paths? shownDetail)? trailing;

  /// Forwarded to WithTopBar in both modes: a persistent gate (freemium)
  /// spans the full body — both panes on expanded windows — while the top
  /// bar stays usable above it.
  final Widget? overlay;

  /// Content width cap in expanded (two-pane) mode.
  final double maxWidth;

  const WithDetailPane({
    super.key,
    required this.title,
    this.screenSemanticsId,
    required this.master,
    required this.detailPaths,
    this.initialDetail,
    this.initialDetailArguments,
    this.placeholder,
    this.paneArguments,
    this.trailing,
    this.overlay,
    // ignore: deprecated_member_use_from_same_package
    this.maxWidth = maxContentWidthTablet,
  });

  @override
  State<StatefulWidget> createState() => WithDetailPaneState();
}

class WithDetailPaneState extends State<WithDetailPane> implements DetailPaneHandle {
  late final _hosts = Core.get<DetailPaneHosts>();
  late final _routes = Core.get<DetailRoutes>();

  /// Pane scroll context is separate from the master's, whose scroll
  /// drives the top-bar blur via WithTopBar's PrimaryScrollController.
  final ScrollController _paneScroll = ScrollController();

  ModalRoute? _route;
  bool _expanded = false;
  Paths? _path;
  Object? _arguments;

  @override
  void initState() {
    super.initState();
    _hosts.register(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _hosts.unregister(this);
    _paneScroll.dispose();
    super.dispose();
  }

  @override
  bool get isActive => mounted && (_route?.isCurrent ?? true) && _expanded;

  @override
  bool accepts(Paths path) => widget.detailPaths.contains(path);

  @override
  void show(Paths path, Object? arguments) {
    setState(() {
      _path = path;
      _arguments = arguments;
    });
  }

  @override
  Widget build(BuildContext context) {
    _expanded = windowShapeOf(context) == WindowShape.expanded;

    final content = _expanded ? _buildTwoPane(context) : _buildSinglePane(context);
    final id = widget.screenSemanticsId;
    if (id == null) return content;
    return Semantics(identifier: id, child: content);
  }

  Widget _buildSinglePane(BuildContext context) {
    return WithTopBar(
      title: widget.title,
      topBarTrailing: widget.trailing?.call(context, null),
      overlay: widget.overlay,
      child: widget.master,
    );
  }

  Widget _buildTwoPane(BuildContext context) {
    final path = _path ?? widget.initialDetail;
    final route = path == null ? null : _routes.resolve(path);
    final tapArguments = _path != null ? _arguments : widget.initialDetailArguments;
    final arguments =
        path == null ? null : (widget.paneArguments?.call(path, tapArguments) ?? tapArguments);

    final pane = (route?.body == null)
        ? (widget.placeholder ?? const DetailPanePlaceholder())
        : route!.buildPane(context, arguments);

    return WithTopBar(
      title: widget.title,
      maxWidth: widget.maxWidth,
      overlay: widget.overlay,
      topBarTrailing: widget.trailing != null
          ? widget.trailing!(context, path)
          : route?.trailing?.call(context, arguments),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: widget.master,
          ),
          Expanded(
            flex: 1,
            child: PrimaryScrollController(
              controller: _paneScroll,
              child: pane,
            ),
          ),
        ],
      ),
    );
  }
}
