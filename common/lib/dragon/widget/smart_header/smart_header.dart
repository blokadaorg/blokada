import 'package:common/common/model.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/smart_header/smart_header_button.dart';
import 'package:common/lock/lock.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/cupertino.dart';

class SmartHeader extends StatefulWidget {
  final FamilyPhase phase;

  const SmartHeader({super.key, required this.phase});

  @override
  State<StatefulWidget> createState() => SmartHeaderState();
}

class SmartHeaderState extends State<SmartHeader>
    with TickerProviderStateMixin, TraceOrigin {
  late final _lock = dep<LockStore>();
  late final _stage = dep<StageStore>();

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
            children: _buildButtons(context),
          ),
        ),
        //SmartHeaderOnboard(key: _containerKey, opened: _opened),
      ],
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final list = <Widget>[];

    //if (!widget.phase.isLocked2()) {
    // list.add(SmartHeaderButton(
    //     icon: CupertinoIcons.qrcode_viewfinder,
    //     onTap: () async {
    //       await traceAs("tappedScan", (trace) async {
    //         await _stage.showModal(trace, StageModal.accountChange);
    //       });
    //     }));
    //}

    list.add(const Spacer());

    if (!widget.phase.isLocked2() &&
        widget.phase != FamilyPhase.linkedExpired &&
        widget.phase != FamilyPhase.fresh) {
      // list.add(SmartHeaderButton(
      //     icon: _lock.hasPin ? CupertinoIcons.lock : CupertinoIcons.lock_open,
      //     onTap: () {
      //       //_modal.set(StageModal.lock);
      //       traceAs("tappedLock", (trace) async {
      //         await _lock.autoLock(trace);
      //       });
      //     }));
      list.add(SmartHeaderButton(
          icon: CupertinoIcons.settings,
          onTap: () {
            Navigation.open(context, Paths.settings);
          }));
      list.add(const SizedBox(width: 4));
    }

    list.add(SmartHeaderButton(
        icon: CupertinoIcons.question_circle,
        onTap: () {
          traceAs("tappedHelp", (trace) async {
            _stage.showModal(trace, StageModal.help);
          });
          // showCupertinoModalBottomSheet(
          //   context: context,
          //   duration: const Duration(milliseconds: 300),
          //   backgroundColor: context.theme.bgColorCard,
          //   builder: (context) => PaymentSheet(),
          // );
        }));

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
