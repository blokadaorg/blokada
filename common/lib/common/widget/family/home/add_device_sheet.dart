import 'package:common/family/family.dart';
import 'package:common/mock/widget/common_clickable.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vistraced/via.dart';
import 'package:unique_names_generator/unique_names_generator.dart' as names;

import '../../../../journal/journal.dart';
import '../../../../mock/widget/add_profile_sheet.dart';
import '../../../../mock/widget/common_card.dart';
import '../../../../mock/widget/common_divider.dart';
import '../../../../mock/widget/common_item.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../util/di.dart';
import '../../../../util/trace.dart';
import '../../../widget.dart';
import 'devices.dart';
import 'top_bar.dart';

part 'add_device_sheet.g.dart';

final _generator = names.UniqueNamesGenerator(
  config: names.Config(
    length: 1,
    seperator: " ",
    style: names.Style.capital,
    dictionaries: [names.animals],
  ),
);

class AddDeviceSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _$AddDeviceSheetState();
}

@Injected(onlyVia: true, immediate: true)
class AddDeviceSheetState extends State<AddDeviceSheet> with TraceOrigin {
  late final _modal = Via.as<StageModal?>()..also(dismissOnClose);
  late final _family = dep<FamilyStore>();
  late final _journal = dep<JournalStore>();

  bool _showQr = false; // The widget would stutter animation, show async
  String _name = "";

  final _topBarController = TopBarController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _name = _generator.generate();

    traceAs("addDevice", (trace) async {
      _family.setWaitingForDevice(trace, _name);
      _journal.setFrequentRefresh(trace, true);
    });
    _family.deviceFound = () {
      // bug: will not stop refreshing often when dismissed sheet
      close();
    };
    _topBarController.manualPush("Add a device");
    _scrollController.addListener(_updateTopBar);
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
    _scrollController.removeListener(_updateTopBar);
    super.dispose();
  }

  close() {
    traceAs("closeAddDevice", (trace) async {
      Navigator.of(context).pop();
      _journal.setFrequentRefresh(trace, false);
    });
  }

  dismissOnClose() {
    // if (_modal.now == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showQr) {
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text("DEVICE SETTINGS",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: context.theme.textSecondary)),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 500),
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
                                      deviceName: _name);
                                },
                                icon: CupertinoIcons.person_crop_circle,
                                text: "Blocklist Profile",
                                trailing: Row(
                                  children: [
                                    Icon(CupertinoIcons.person_solid,
                                        color: Colors.green, size: 18),
                                    SizedBox(width: 4),
                                    Text("Child",
                                        style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                              ),
                              CommonDivider(),
                              CommonItem(
                                onTap: () {
                                  showRenameDialog(context, "device", _name);
                                },
                                icon: CupertinoIcons.device_phone_portrait,
                                text: "Name",
                                trailing: Text(_name,
                                    style: TextStyle(
                                        color: context.theme.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    _showQr
                        ? Row(
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
                                  data: _generateLink(_name),
                                  version: QrVersions.auto,
                                  size: 200.0,
                                ),
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

  String _generateLink(String name) {
    return _family.onboardLinkTemplate.replaceAll("NAME", name.urlEncode);
  }
}
