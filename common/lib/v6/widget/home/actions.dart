import 'package:common/common/widget/anim/sliding.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/start/start.dart';
import 'package:common/v6/widget/home/plusbutton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import 'counter.dart';

class HomeActions extends StatefulWidget {
  const HomeActions({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeActionsState();
  }
}

class _HomeActionsState extends State<HomeActions>
    with TickerProviderStateMixin, Logging {
  final _app = DI.get<AppStore>();
  final _appStart = DI.get<AppStartStore>();

  late final AnimationController _ctrlCounter = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  late final AnimationController _ctrlPlus = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();

    autorun((_) async {
      final status = _app.status;

      if (status.isActive()) {
        _ctrlCounter.forward();
        await sleepAsync(const Duration(milliseconds: 100));
        _ctrlPlus.forward();
      } else {
        _ctrlCounter.reverse();
        await sleepAsync(const Duration(milliseconds: 100));
        _ctrlPlus.reverse();
      }
    });
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
                      ? "home action tap to activate".i18n
                      : "home status detail progress".i18n,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Column(
              children: [
                Sliding(controller: _ctrlCounter, child: HomeCounter2()),
                const SizedBox(height: 16),
                Sliding(controller: _ctrlPlus, child: PlusButton()),
              ],
            ),
          ],
        ),
      );
    });
  }
}
