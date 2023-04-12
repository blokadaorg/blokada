import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../app/app.dart';
import '../app/channel.pg.dart';
import '../util/di.dart';
import 'myapp.dart';

class PlusButton extends StatefulWidget {
  PlusButton({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PlusButtonState();
  }
}

class _PlusButtonState extends State<PlusButton> with TickerProviderStateMixin {
  final _app = di<AppStore>();

  // TODO: once plusRepo is here, check commented code

  var pressed = false;
  var location = "";
  var isPlus = false;
  var working = true;
  var active = false;
  // TODO: working state ignore touches?

  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0.0, 10.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  ));

  @override
  void initState() {
    super.initState();

    mobx.autorun((_) {
      final status = _app.status;
      setState(() {
        location = "TODO";
        pressed = status == AppStatus.activatedPlus;
        working = status.isWorking();
        active = status.isActive();
        isPlus = false; // TODO; is plus
      });

      if (active && !working) {
        _controller.forward();
      } else if (!active && !working) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: working,
      child: SlideTransition(
        position: _slideAnim,
        child: SizedBox(
            width: 300,
            height: 48,
            child: Stack(
              children: [
                // When switch is off
                AnimatedOpacity(
                    opacity: pressed ? 0 : 1,
                    duration: Duration(milliseconds: 500),
                    child: ElevatedButton(
                        onPressed: () {
                          // plusRepo.openLocations();
                        },
                        child: _buildButtonContent())),
                // When switch is on
                AnimatedOpacity(
                    opacity: pressed ? 1 : 0,
                    duration: Duration(milliseconds: 500),
                    child: OutlinedButton(
                        onPressed: () {
                          // plusRepo.openLocations();
                        },
                        child: _buildButtonContent())),
                // When account is not Plus (CTA)
                IgnorePointer(
                  ignoring: isPlus,
                  child: AnimatedOpacity(
                      opacity: isPlus ? 0 : 1,
                      duration: Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: () {
                          // plusRepo.openLocations();
                        },
                        child: Flex(direction: Axis.horizontal, children: [
                          Expanded(
                              child: Align(
                                  child: Text("universal action upgrade".i18n)))
                        ]),
                      )),
                )

                // Expanded(
                //   child: Align(
                //     alignment: Alignment.centerRight,
                //     child: CupertinoSwitch(
                //       value: pressed,
                //       activeColor: Colors.black54,
                //       onChanged: (value) {
                //         setState(() {
                //           pressed = value;
                //         });
                //       },
                //     ),
                //   ),
                // )
              ],
            )),
      ),
    );
  }

  Widget _buildButtonContent() {
    final theme = Theme.of(context).extension<BrandTheme>()!;

    return Row(
      children: [
        pressed
            ? (Text("home plus button location"
                .i18n
                .fill([location]).replaceAll("*", "")))
            : (Text("home plus button select location".i18n)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: pressed,
              activeColor: theme.plus,
              onChanged: (value) {
                setState(() {
                  // if (appRepo.appState.location.isEmpty) {
                  //   plusRepo.openLocations();
                  // } else {
                  //   pressed = value;
                  //   plusRepo.switchPlus(value);
                  // }
                });
              },
            ),
          ),
        )
      ],
    );
  }
}
