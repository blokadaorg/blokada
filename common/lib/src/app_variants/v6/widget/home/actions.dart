import 'package:common/src/shared/ui/anim/sliding.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/app_variants/v6/widget/home/counter.dart';
import 'package:common/src/app_variants/v6/widget/home/freemium.dart';
import 'package:common/src/app_variants/v6/widget/home/plusbutton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

/// The area under the power button on Home. While protection is off it shows
/// the "tap to activate" (or paused) hint; once active it slides in the
/// counter and then the Plus button, 100 ms apart, so the two arrive as a
/// staggered pair rather than at once. It owns both animation controllers so
/// a single reaction to the app status can drive them in that order.
class HomeActions extends StatefulWidget {
  const HomeActions({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeActionsState();
  }
}

class _HomeActionsState extends State<HomeActions> with TickerProviderStateMixin, Logging {
  final _app = Core.get<AppStore>();
  final _appStart = Core.get<AppStartStore>();
  final _account = Core.get<AccountStore>();

  late final AnimationController _ctrlCounter = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  late final AnimationController _ctrlPlus = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  // Disposed with the widget: an autorun outlives the State and would keep
  // driving the controllers after they are disposed.
  ReactionDisposer? _disposeStatusReaction;

  @override
  void initState() {
    super.initState();

    _disposeStatusReaction = autorun((_) async {
      final status = _app.status;

      if (status.isActive()) {
        _ctrlCounter.forward();
        await sleepAsync(const Duration(milliseconds: 100));
        if (!mounted) return;
        _ctrlPlus.forward();
      } else {
        _ctrlCounter.reverse();
        await sleepAsync(const Duration(milliseconds: 100));
        if (!mounted) return;
        _ctrlPlus.reverse();
      }
    });
  }

  @override
  void dispose() {
    _disposeStatusReaction?.call();
    _ctrlCounter.dispose();
    _ctrlPlus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final status = _app.status;

      return SizedBox(
        width: 300,
        child: Stack(
          alignment: AlignmentDirectional.topCenter,
          children: [
            AnimatedOpacity(
              opacity: status.isActive() ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInExpo,
              child: GestureDetector(
                onTap: () {
                  if (status.isWorking()) return;
                  log(Markers.userTap).trace("tappedStatusText", (m) async {
                    await _appStart.toggleApp(m);
                  });
                },
                child: Text(
                  status.isInactive()
                      ? ((_appStart.pausedForAccurate != null)
                          ? "home status detail paused".i18n
                          : "home action tap to activate".i18n)
                      : "home status detail progress".i18n,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Column(
              children: [
                Sliding(
                    controller: _ctrlCounter,
                    child: _account.isFreemium ? const FreemiumCounter() : const HomeCounter()),
                const SizedBox(height: 16),
                Sliding(
                    controller: _ctrlPlus, child: _account.isFreemium ? Container() : PlusButton()),
              ],
            ),
          ],
        ),
      );
    });
  }
}
