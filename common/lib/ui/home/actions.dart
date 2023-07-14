import 'package:common/service/I18nService.dart';
import 'package:common/util/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../app/start/start.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../anim/sliding.dart';
import '../touch.dart';
import 'plusbutton.dart';
import 'counter.dart';

class HomeActions extends StatefulWidget {
  const HomeActions({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeActionsState();
  }
}

class _HomeActionsState extends State<HomeActions>
    with TickerProviderStateMixin, TraceOrigin {
  final _app = dep<AppStore>();
  final _appStart = dep<AppStartStore>();

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
                  traceAs("tappedStatusText", (trace) async {
                    await _appStart.toggleApp(trace);
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
