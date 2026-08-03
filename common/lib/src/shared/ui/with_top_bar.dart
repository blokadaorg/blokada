import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WithTopBar extends StatefulWidget {
  final String title;
  final Widget? topBarTrailing;
  final double maxWidth;
  final Widget child;

  /// Full-bleed layer above the width-constrained content but below the
  /// top bar chrome. Exists for persistent gates (freemium): the gate must
  /// blur and center over the WHOLE body — both panes on expanded windows,
  /// not the section it used to be embedded in — while the title and back
  /// affordance stay tappable so the user can still navigate away.
  final Widget? overlay;

  const WithTopBar({
    super.key,
    required this.title,
    this.topBarTrailing,
    this.maxWidth = maxContentWidth,
    this.overlay,
    required this.child,
  });

  @override
  State<StatefulWidget> createState() => WithTopBarState();
}

class WithTopBarState extends State<WithTopBar> {
  late TopBarController _topBarCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_updateTopBar);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_updateTopBar);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _updateTopBar() {
    _topBarCtrl.updateScrollPos(_scrollCtrl.offset);
  }

  @override
  Widget build(BuildContext context) {
    _topBarCtrl = Provider.of<TopBarController>(context);
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: PrimaryScrollController(
        controller: _scrollCtrl,
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: widget.child,
              ),
            ),
            if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
            TopBar(title: widget.title, trailing: widget.topBarTrailing),
          ],
        ),
      ),
    );
  }
}
