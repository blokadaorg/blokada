import 'dart:async';

import 'package:common/common/dialog.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/widget/profile/profile_utils.dart';
import 'package:common/platform/family/family.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LinkDeviceSheet extends StatefulWidget {
  final JsonDevice? device;

  const LinkDeviceSheet({super.key, this.device});

  @override
  State<StatefulWidget> createState() => LinkDeviceSheetState();
}

class LinkDeviceSheetState extends State<LinkDeviceSheet> with Logging {
  late final _family = Core.get<FamilyActor>();
  late final _familyLink = Core.get<LinkActor>();
  late final _generator = Core.get<NameGenerator>();
  late final _channel = Core.get<FamilyChannel>();

  bool _showQr = false; // The widget would stutter animation, show async

  late LinkingDevice _payload;
  bool isReady = false;

  final _topBarController = TopBarController();

  @override
  void initState() {
    super.initState();

    _familyLink.linkDeviceHeartbeatReceived = () {
      close();
    };

    _setDeviceTemplate();
  }

  _setDeviceTemplate({String? name, JsonProfile? profile}) async {
    await log(Markers.ui).trace("setDeviceAdding", (m) async {
      await _familyLink.cancelLinkDevice(m);
      _payload = await _familyLink.initiateLinkDevice(
          name ?? _getProbablyUniqueRandomName(), profile, widget.device, m);
      setState(() {
        isReady = true;
      });
    });
  }

  String _getProbablyUniqueRandomName() {
    final existing =
        _family.devices.now.entries.map((e) => e.device.alias).toSet();
    int attempts = 5;
    String name = _generator.get();
    while (attempts-- > 0) {
      if (!existing.contains(name)) return name;
      name = _generator.get();
    }
    return name;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topBarController.backgroundColor = context.theme.bgColorCard;
  }

  @override
  void dispose() {
    log(Markers.ui).trace("linkDeviceDismiss", (m) async {
      await _familyLink.cancelLinkDevice(m);
    });
    super.dispose();
  }

  close() {
    log(Markers.userTap).trace("closeLinkDevice", (m) async {
      _familyLink.cancelLinkDevice;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
                        Text(
                            widget.device == null
                                ? "family link description new".i18n
                                : "family link description again".i18n,
                            softWrap: true,
                            textAlign: TextAlign.justify,
                            style:
                                TextStyle(color: context.theme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  _showQr
                      ? Column(
                          children: [
                            widget.device != null
                                ? Container()
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Text(
                                        "family device label settings".i18n,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                context.theme.textSecondary)),
                                  ),
                            widget.device != null
                                ? Container()
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: CommonCard(
                                      bgColor: context.theme.bgColor,
                                      child: Column(
                                        children: [
                                          CommonItem(
                                            onTap: () {
                                              showRenameDialog(
                                                  context,
                                                  "device",
                                                  _payload.device.alias,
                                                  onConfirm: (name) =>
                                                      _setDeviceTemplate(
                                                          name: name,
                                                          profile: _payload
                                                              .profile));
                                            },
                                            icon: CupertinoIcons
                                                .device_phone_portrait,
                                            text:
                                                "account lease label name".i18n,
                                            trailing: Text(
                                                _payload.device.alias,
                                                style: TextStyle(
                                                    color: context
                                                        .theme.textSecondary)),
                                          ),
                                          const CommonDivider(),
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
                                            icon: CupertinoIcons
                                                .person_crop_circle,
                                            text: "family stats label profile"
                                                .i18n,
                                            trailing: Row(
                                              children: [
                                                Icon(
                                                    getProfileIcon(_payload
                                                        .profile!.template),
                                                    color: getProfileColor(
                                                        _payload
                                                            .profile!.template),
                                                    size: 18),
                                                const SizedBox(width: 4),
                                                Text(
                                                    _payload.profile!
                                                        .displayAlias.i18n,
                                                    style: TextStyle(
                                                        color: getProfileColor(
                                                            _payload.profile!
                                                                .template))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 60),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 66),
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
                                Padding(
                                  padding: const EdgeInsets.all(11.0),
                                  child: CommonClickable(
                                    onTap: () async {
                                      // To prevent UI freeze when the share screen opens
                                      await sleepAsync(
                                          const Duration(milliseconds: 500));
                                      _channel.doShareUrl(_payload.qrUrl);
                                    },
                                    child: const Icon(CupertinoIcons.share,
                                        size: 24),
                                  ),
                                )
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopBar(
                height: 58,
                bottomPadding: 16,
                title: widget.device == null
                    ? "family device header add".i18n
                    : "family device header link".i18n,
                animateBg: true,
                trailing: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: CommonClickable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text("universal action cancel".i18n,
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
