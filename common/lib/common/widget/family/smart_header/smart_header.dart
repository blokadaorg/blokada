import 'package:common/common/widget.dart';
import 'package:common/mock/widget/mock_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:vistraced/via.dart';

import '../../../../lock/lock.dart';
import '../../../../mock/widget/payment_sheet.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../util/di.dart';
import '../../../../util/trace.dart';
import '../../../model.dart';
import 'smart_header_button.dart';

part 'smart_header.g.dart';

class SmartHeader extends StatefulWidget {
  final FamilyPhase phase;

  const SmartHeader({super.key, required this.phase});

  @override
  State<StatefulWidget> createState() => _$SmartHeaderState();
}

@Injected(onlyVia: true, immediate: true)
class SmartHeaderState extends State<SmartHeader>
    with TickerProviderStateMixin, TraceOrigin {
  @MatcherSpec(of: "familyUnlink")
  late final _unlink = Via.call();
  late final _modal = Via.as<StageModal?>();
  late final _lock = dep<LockStore>();

  // bool _opened = false;

  // late final _ctrl = AnimationController(
  //   duration: const Duration(milliseconds: 400),
  //   vsync: this,
  // );
  //
  // late final _anim = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
  //   parent: _ctrl,
  //   curve: Curves.easeInOut,
  // ));

  // @override
  // void dispose() {
  //   super.dispose();
  //   _ctrl.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  SmartHeaderButton(
                      icon: CupertinoIcons.question_circle,
                      onTap: () {
                        //_modal.set(StageModal.help);

                        showCupertinoModalBottomSheet(
                          context: context,
                          duration: const Duration(milliseconds: 300),
                          backgroundColor: context.theme.bgColorCard,
                          builder: (context) => PaymentSheet(),
                        );
                      }),
                  SizedBox(width: 4),
                ] +
                _buildButtons(context),
          ),
        ),
        //SmartHeaderOnboard(key: _containerKey, opened: _opened),
      ],
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final list = <Widget>[];

    if (!widget.phase.isLocked2()) {
      list.add(SmartHeaderButton(
          icon: CupertinoIcons.qrcode_viewfinder,
          onTap: () {
            _modal.set(StageModal.accountChange);
          }));
    }

    list.add(Spacer());

    if (!widget.phase.isLocked2() &&
        widget.phase != FamilyPhase.linkedUnlocked) {
      list.add(SmartHeaderButton(
          icon: _lock.hasPin ? CupertinoIcons.lock : CupertinoIcons.lock_open,
          onTap: () {
            //_modal.set(StageModal.lock);
            traceAs("tappedLock", (trace) async {
              await _lock.autoLock(trace);
            });
          }));
      list.add(SizedBox(width: 4));
      list.add(SmartHeaderButton(
          icon: CupertinoIcons.settings,
          onTap: () {
            Navigator.pushNamed(context, "/settings");
          }));
    }

    return list;
  }
}

// GestureDetector(
//   onTap: _playAnim,
//   child: SmartHeaderButton(
//       iconWidget: Padding(
//     padding: const EdgeInsets.all(12),
//     child: Opacity(
//       opacity: _opened ? 0 : 1,
//       child: Image.asset(
//         "assets/images/family-logo.png",
//         fit: BoxFit.contain,
//       ),
//     ),
//   )),
// ),
