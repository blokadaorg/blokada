import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/features/rate/domain/rate.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/modal/ui/blur_background.dart';
import 'package:common/src/shared/ui/text_scale.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import 'star.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> with Logging {
  final _rate = Core.get<RateActor>();

  int _rating = 0;
  bool _showPlatformDialog = false;

  final _duration = const Duration(milliseconds: 200);

  GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        // _isLocked = _lock.isLocked;
        // _hasPin = _lock.hasPin;
      });
    });
  }

  _close() => _rate.onUserTapRate(_rating, _showPlatformDialog);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Material(
      type: MaterialType.transparency,
      child: BlurBackground(
        key: bgStateKey,
        onClosed: _close,
        child: Semantics(
          identifier: AutomationIds.rateModal,
          container: true,
          explicitChildNodes: true,
          child: Container(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildRateBody(theme),
            ),
          ),
        ),
      ),
    );
  }

  /// Sits at the bottom of the screen, within thumb reach; scrolls when a
  /// short screen or large text needs more room, so Cancel stays reachable.
  /// The scroll view only takes vertical drags when its content does not fit,
  /// so the swipe up to close keeps working otherwise.
  Widget _buildRateBody(BlokadaTheme theme) {
    // At large text sizes Cancel stays pinned below the scrolling content
    // rather than at its end, which can be screens away.
    final pinned = isLargeTextScale(context);
    final scroll = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _buildRateContent(theme, withCancel: !pinned),
        ),
      ),
    );
    if (!pinned) return scroll;
    return Column(
      children: [
        Expanded(child: scroll),
        _buildCancel(large: true),
      ],
    );
  }

  Widget _buildRateContent(BlokadaTheme theme, {required bool withCancel}) {
    final large = isLargeTextScale(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Image.asset(
          Core.act.isFamily ? "assets/images/family-logo.png" : "assets/images/blokada_logo.png",
          fit: BoxFit.contain,
          // Smaller at large text sizes, leaving the room to the text.
          width: large ? 72 : 128,
          height: large ? 72 : 128,
        ),
        const SizedBox(height: 30),
        WordFitText(
          "main rate us header".i18n,
          maxScale: TextScaleCeiling.headline,
          textAlign: TextAlign.center,
          style: context.theme.text.hero.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 30),
        Text(
          "main rate us description".i18n,
          textAlign: TextAlign.start,
          style: context.theme.text.body.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RateStar(full: _rating >= 1, onTap: () => setState(() => _rating = 1)),
            RateStar(full: _rating >= 2, onTap: () => setState(() => _rating = 2)),
            RateStar(full: _rating >= 3, onTap: () => setState(() => _rating = 3)),
            RateStar(full: _rating >= 4, onTap: () => setState(() => _rating = 4)),
            RateStar(full: _rating >= 5, onTap: () => setState(() => _rating = 5)),
          ],
        ),
        SizedBox(height: large ? 32 : 80),
        AnimatedOpacity(
          opacity: _rating > 0 ? 1.0 : 0.0,
          duration: _duration,
          child: Column(
            children: [
              AnimatedOpacity(
                opacity: _rating >= 4 ? 1.0 : 0.0,
                duration: _duration,
                child: Text(
                  "main rate us on app store".i18n,
                  textAlign: TextAlign.start,
                  style: context.theme.text.body.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              MiniCard(
                onTap: () {
                  _showPlatformDialog = true;
                  bgStateKey.currentState?.animateToClose();
                },
                color: theme.accent,
                child: SizedBox(
                  width: 200,
                  child: Text(
                    _rating >= 4
                        ? "main rate us action sure".i18n
                        : "universal action continue".i18n,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.theme.onAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (withCancel) _buildCancel(large: large),
      ],
    );
  }

  Widget _buildCancel({required bool large}) {
    return AnimatedOpacity(
      opacity: _rating > 0 && _rating < 4 ? 0.0 : 1.0,
      duration: _duration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // A big tap target at the bottom right, a little smaller at
          // large text sizes so the label keeps the room.
          Flexible(
            child: GestureDetector(
              onTap: () {
                bgStateKey.currentState?.animateToClose();
              },
              child: Semantics(
                identifier: AutomationIds.rateDismiss,
                button: true,
                child: Padding(
                  padding: large
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 32)
                      : const EdgeInsets.symmetric(horizontal: 40, vertical: 64),
                  child: WordFitText(
                    "universal action cancel".i18n,
                    style: context.theme.text.headline.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
