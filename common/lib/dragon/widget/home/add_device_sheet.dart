import 'package:common/common/model.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/device/generator.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/home/top_bar.dart';
import 'package:common/dragon/widget/profile_utils.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AddDeviceSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AddDeviceSheetState();
}

class AddDeviceSheetState extends State<AddDeviceSheet> with TraceOrigin {
  late final _family = dep<FamilyStore>();
  late final _generator = dep<NameGenerator>();

  bool _showQr = false; // The widget would stutter animation, show async

  late AddingDevice _payload;
  bool isReady = false;

  final _topBarController = TopBarController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _family.addingDeviceHeartbeatReceived = () {
      close();
    };
    _topBarController.manualPush("Add a device");
    _scrollController.addListener(_updateTopBar);

    _setDeviceTemplate();
  }

  _setDeviceTemplate({String? name, JsonProfile? profile}) async {
    await traceAs("setDeviceAdding", (trace) async {
      await _family.cancelAddDevice(trace);
      _payload = await _family.initiateAddDevice(
          trace, name ?? _generator.get(), profile);
    });
    setState(() {
      isReady = true;
    });
  }

  _updateTopBar() {
    _topBarController.updateScrollPos(_scrollController.offset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topBarController.backgroundColor = context.theme.bgColorCard;
  }

  @override
  void dispose() {
    traceAs("addDeviceDismiss", (trace) async {
      await _family.cancelAddDevice(trace);
    });
    _scrollController.removeListener(_updateTopBar);
    super.dispose();
  }

  close() {
    traceAs("closeAddDevice", (trace) async {
      _family.cancelAddDevice(trace);
      Navigator.of(context).pop();
    });
  }

  dismissOnClose() {
    // if (_modal.now == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showQr && isReady) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        setState(() => _showQr = true);
      });
    }

    return Scaffold(
      backgroundColor: context.theme.bgColorCard,
      body: ChangeNotifierProvider(
        create: (context) => _topBarController,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: PrimaryScrollController(
                controller: _scrollController,
                child: ListView(
                  children: [
                    const SizedBox(height: 48),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        children: [
                          Text(
                              "Scan the QR code below with the device you want to add to your family. This screen will close once the device is detected.",
                              softWrap: true,
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                  color: context.theme.textSecondary)),
                          // Text("- or -",
                          //     style: TextStyle(
                          //         color: context.theme.textSecondary, fontSize: 16)),
                          // const SizedBox(height: 12),
                          // Row(
                          //   children: [
                          //     // Icon(CupertinoIcons.lock_open,
                          //     //     color: context.theme.family),
                          //     // const SizedBox(width: 12),
                          //     Expanded(
                          //       child: MiniCard(
                          //         //onTap: _handleCtaTap(),
                          //         color: context.theme.family,
                          //         child: SizedBox(
                          //           height: 32,
                          //           child: Center(
                          //             child: Text(
                          //               "Use this device",
                          //               style: const TextStyle(
                          //                   color: Colors.white,
                          //                   fontWeight: FontWeight.w600),
                          //             ),
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        ],
                      ),
                    ),
                    SizedBox(height: 60),
                    _showQr
                        ? Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text("DEVICE SETTINGS",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: context.theme.textSecondary)),
                              ),
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 500),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: CommonCard(
                                    bgColor: context.theme.bgColor,
                                    child: Column(
                                      children: [
                                        CommonItem(
                                          onTap: () {
                                            showSelectProfileDialog(context,
                                                device: _payload.device,
                                                onSelected: (p) {
                                              _setDeviceTemplate(
                                                  name: _payload.device.alias,
                                                  profile: p);
                                            });
                                          },
                                          icon:
                                              CupertinoIcons.person_crop_circle,
                                          text: "Blocklist Profile",
                                          trailing: Row(
                                            children: [
                                              Icon(
                                                  getProfileIcon(_payload
                                                      .profile.template),
                                                  color: getProfileColor(
                                                      _payload
                                                          .profile.template),
                                                  size: 18),
                                              SizedBox(width: 4),
                                              Text(
                                                  _payload.profile.displayAlias,
                                                  style: TextStyle(
                                                      color: getProfileColor(
                                                          _payload.profile
                                                              .template))),
                                            ],
                                          ),
                                        ),
                                        CommonDivider(),
                                        CommonItem(
                                          onTap: () {
                                            showRenameDialog(context, "device",
                                                _payload.device.alias,
                                                onConfirm: (name) =>
                                                    _setDeviceTemplate(
                                                        name: name,
                                                        profile:
                                                            _payload.profile));
                                          },
                                          icon: CupertinoIcons
                                              .device_phone_portrait,
                                          text: "Name",
                                          trailing: Text(_payload.device.alias,
                                              style: TextStyle(
                                                  color: context
                                                      .theme.textSecondary)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 60),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: context.theme.divider
                                              .withOpacity(0.05),
                                          width: 2,
                                        )),
                                    child: QrImageView(
                                      data: _payload.qrUrl,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox(height: 200),
                    const SizedBox(height: 48),
                    const CupertinoActivityIndicator(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopBar(
                height: 58,
                bottomPadding: 16,
                title: "Add a device",
                animateBg: true,
                trailing: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: CommonClickable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text("Cancel",
                        style: TextStyle(color: context.theme.accent)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
