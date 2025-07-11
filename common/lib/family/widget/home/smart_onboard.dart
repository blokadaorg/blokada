import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/home/big_icon.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SmartOnboard extends StatefulWidget {
  final FamilyPhase phase;
  final int deviceCount;

  const SmartOnboard({
    super.key,
    required this.phase,
    required this.deviceCount,
  });

  @override
  State<StatefulWidget> createState() => SmartOnboardState();
}

class SmartOnboardState extends State<SmartOnboard>
    with TickerProviderStateMixin, Logging {
  late final _stage = Core.get<StageStore>();
  late final _family = Core.get<FamilyActor>();
  late final _payment = Core.get<PaymentActor>();
  late final _modal = Core.get<CurrentModalValue>();

  @override
  Widget build(BuildContext context) {
    final texts = _getTexts(widget.phase, widget.deviceCount);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            //const SizedBox(height: 80),
            widget.deviceCount > 2
                ? const SizedBox(
                    height: 64,
                    child: Image(
                      image: AssetImage('assets/images/header.png'),
                      width: 100,
                    ),
                  )
                : Container(height: 64),
            const SizedBox(height: 52),
            BigIcon(
              icon: getIcon(widget.phase),
              canShowLogo: !(widget.phase == FamilyPhase.parentHasDevices &&
                  widget.deviceCount > 2),
            ),
            SizedBox(height: PlatformInfo().isSmallAndroid(context) ? 45 : 90),
            Text(
              texts.first!,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (texts.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: SizedBox(
                  height: 80,
                  child: Text(
                    texts[1]!,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.start,
                    maxLines: 3,
                  ),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 64,
              child: widget.phase.requiresBigCta()
                  ? _buildButton(context)
                  : Container(),
            ),
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: MiniCard(
              onTap: _handleCtaTap,
              color: context.theme.accent,
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      getIcon(widget.phase, forCta: true),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Center(
                      child: Text(
                        getCtaText(widget.phase),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          widget.phase != FamilyPhase.fresh
              ? Container()
              : Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 120,
                    child: MiniCard(
                      onTap: () {
                        log(Markers.userTap).trace("tappedLink", (m) async {
                          await _stage.showModal(StageModal.accountChange, m);
                        });
                      },
                      color: context.theme.textPrimary.withOpacity(0.15),
                      child: SizedBox(
                        height: 32,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              getIcon(FamilyPhase.linkedExpired, forCta: true),
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Center(
                              child: Text(
                                getCtaText(FamilyPhase.linkedExpired),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  _handleCtaTap() async {
    final p = widget.phase;

    if (p.requiresActivation()) {
      log(Markers.userTap).trace("handleCtaTap", (m) async {
        await _family.activateCta(false, m);
      });
    } else if (p.requiresPerms()) {
      _payment.reportOnboarding(OnboardingStep.permsPrompted);
      _modal.change(Markers.userTap, Modal.onboardPrivateDns);
    } else if (p.isLocked2()) {
      log(Markers.userTap).trace("handleCtaTap", (m) async {
        await _stage.showModal(StageModal.lock, m);
      });
      // } else if (!_devices.now.hasThisDevice) {
      // await _modal.set(StageModal.onboardingAccountDecided);
    } else if (p == FamilyPhase.linkedExpired) {
      log(Markers.userTap).trace("tappedLinkExpired", (m) async {
        await _stage.showModal(StageModal.accountChange, m);
      });
    } else {
      _modal.change(Markers.userTap, Modal.familyLinkDevice);
    }
  }

  List<String?> _getTexts(FamilyPhase phase, int devicesCount) {
    switch (phase) {
      case FamilyPhase.fresh:
        return [
          "family status fresh header".i18n,
          "${"family status fresh body".i18n}\n\n",
        ];
      case FamilyPhase.parentNoDevices:
        return [
          "family status ready header".i18n,
          "${"family status ready body".i18n}\n\n",
        ];
      case FamilyPhase.linkedActive:
        return [
          "family status linked header".i18n,
          "${"family status linked body".i18n}\n\n",
        ];
      case FamilyPhase.linkedExpired:
        return [
          "family status perms header".i18n,
          "${"family status qr body".i18n}\n\n",
        ];
      case FamilyPhase.linkedNoPerms ||
            FamilyPhase.lockedNoPerms ||
            FamilyPhase.noPerms:
        return [
          "family status perms header".i18n,
          "${"family status perms body alt".i18n}\n\n",
        ];
      case FamilyPhase.lockedNoAccount:
        return [
          "family status expired header".i18n,
          "${"family status expired body".i18n}\n\n",
        ];
      case FamilyPhase.lockedActive:
        return [
          "family status locked header".i18n,
        ];
      case FamilyPhase.parentHasDevices:
        if (devicesCount > 1) {
          return ["", ""];
        } else {
          return [
            "family status active header".i18n,
            "${"family status active body".i18n}\n\n",
          ];
        }
      case FamilyPhase.starting:
        return ["", "home status detail progress".i18n];
      default:
        return ["", ""];
    }
  }
}

IconData? getIcon(FamilyPhase phase, {bool forCta = false}) {
  switch (phase) {
    case FamilyPhase.fresh || FamilyPhase.lockedNoAccount:
      return CupertinoIcons.person_crop_circle;
    case FamilyPhase.parentNoDevices:
      return CupertinoIcons.add_circled;
    case FamilyPhase.lockedActive:
      return CupertinoIcons.lock;
    case FamilyPhase.linkedExpired || FamilyPhase.linkedActive:
      if (forCta) return CupertinoIcons.qrcode_viewfinder;
      return CupertinoIcons.link;
    case FamilyPhase.linkedNoPerms ||
          FamilyPhase.lockedNoPerms ||
          FamilyPhase.noPerms:
      return Icons.key;
    default:
      return null;
  }
}

String getCtaText(FamilyPhase p) {
  if (p == FamilyPhase.linkedExpired) {
    //return "family account cta unlink".i18n;
    return "family cta action link".i18n;
  } else if (p.requiresPerms()) {
    return "family cta action finish setup".i18n;
  } else if (p.requiresActivation()) {
    return "family cta action activate".i18n;
  } else if (p.isLocked2()) {
    return "family cta action unlock".i18n;
  } else {
    return "family cta action add device".i18n;
  }
}
