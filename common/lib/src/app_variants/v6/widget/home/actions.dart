import 'dart:async';

import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/anim/sliding.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/platform/device/device.dart';
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
///
/// Pause is account-wide in v6, so the off state also says when the pause came
/// from another device (#455); tapping resumes like the power button does.
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
  final _device = Core.get<DeviceStore>();
  final _pauseIssuedHere = Core.get<PauseIssuedHereValue>();

  // Null until loaded: an unknown origin never claims another device.
  bool? _issuedHere;
  // Set by the first change event; a stored value read later is older.
  bool _gotOriginChange = false;
  StreamSubscription? _pauseOriginSub;

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

    _pauseOriginSub = _pauseIssuedHere.onChange.listen((it) {
      _gotOriginChange = true;
      if (!mounted) return;
      setState(() => _issuedHere = it.now);
    });
    _loadStoredOrigin();

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

  /// Reads the stored origin without publishing it. A pause issued while the
  /// read is in flight is newer than what it returns, so the stored value is
  /// only applied when no change arrived meanwhile. (Value.fetch would publish
  /// the stale value as a change of its own.)
  Future<void> _loadStoredOrigin() async {
    final present = _pauseIssuedHere.present;
    if (present != null) {
      _issuedHere = present;
      return;
    }
    final load = _pauseIssuedHere.load;
    if (load == null) return;
    final bool? stored;
    try {
      stored = await load(Markers.ui);
    } catch (e, s) {
      // Unknown origin keeps the plain off state, which is always true.
      log(Markers.ui).e(msg: "Failed reading pause origin", err: e, stack: s);
      return;
    }
    if (!mounted || _gotOriginChange) return;
    setState(() => _issuedHere = stored);
  }

  @override
  void dispose() {
    _disposeStatusReaction?.call();
    _pauseOriginSub?.cancel();
    _ctrlCounter.dispose();
    _ctrlPlus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final status = _app.status;
      final pausedElsewhere = status.isInactive() &&
          isPausedElsewhere(
            accountActive: _account.type.isActive(),
            cloudEnabled: _device.cloudEnabled,
            issuedHere: _issuedHere,
          );

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
                child: Semantics(
                  identifier: pausedElsewhere ? AutomationIds.homePausedElsewhere : null,
                  // Tapping it resumes, so announce it as a button.
                  button: pausedElsewhere,
                  child: Text(
                    status.isInactive()
                        ? (pausedElsewhere
                            ? "${"home status paused elsewhere".i18n} · ${"universal action resume".i18n}"
                            : (_appStart.pausedForAccurate != null)
                                ? "home status detail paused".i18n
                                : "home action tap to activate".i18n)
                        : "home status detail progress".i18n,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
