import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/home/device/home_device.dart';
import 'package:common/src/app_variants/family/widget/home/device/home_device_header.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class HomeDevices extends StatefulWidget {
  final FamilyDevices devices;
  final ParentDeviceProtectionOwner parentDeviceProtectionOwner;

  const HomeDevices({
    super.key,
    required this.devices,
    required this.parentDeviceProtectionOwner,
  });

  @override
  HomeDevicesState createState() => HomeDevicesState();
}

class HomeDevicesState extends State<HomeDevices> with TickerProviderStateMixin, Logging {
  late final _modal = Core.get<CurrentModalValue>();
  late final _slidableOnboarding = Core.get<SlidableOnboarding>();

  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(HomeDevices oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _getDevices(context);

    if (windowShapeOf(context) != WindowShape.expanded || devices.length < 2) {
      // One pane view
      return Container(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: ListView(
          reverse: true,
          children: [_buildAddDeviceButton(context)] + devices,
        ),
      );
    } else {
      // Two pane view
      return Container(
        constraints: const BoxConstraints(maxWidth: maxContentWidth * 2),
        child: ListView(
          reverse: true,
          children: [
            _buildAddDeviceButton(context),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  children: List.generate(
                      (devices.length / 2).floor(),
                      (index) => SizedBox(
                            width: maxContentWidth,
                            child: devices[(devices.length - 1) - (2 * index + 1)],
                          )),
                ),
                Column(
                  children: List.generate(
                      (devices.length / 2).ceil(),
                      (index) => SizedBox(
                            width: maxContentWidth,
                            child: devices[(devices.length - 1) - (2 * index)],
                          )),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  List<Widget> _getDevices(BuildContext context) {
    final priorityDevices = <Widget>[];
    if (widget.devices.hasParentDevicePointer(widget.parentDeviceProtectionOwner)) {
      priorityDevices.add(_wrapPlain(
        HomeBlokadaSixDevicePointer(color: context.theme.accent),
      ));
    } else if (widget.devices.hasThisDevice) {
      final thisDevice = widget.devices.entries.firstWhere((it) => it.thisDevice);
      priorityDevices.add(_buildDeviceCard(context, thisDevice));
    }

    final childDevices = widget.devices
        .visibleEntries(widget.parentDeviceProtectionOwner)
        .filter((e) => !e.thisDevice)
        .map((e) => _buildDeviceCard(context, e))
        .toList();

    return priorityDevices + childDevices;
  }

  Widget _wrapPlain(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: child,
    );
  }

  Widget _buildDeviceCard(BuildContext context, FamilyDevice device) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: _wrapInDismissible(
        context,
        device,
        HomeDevice(
          device: device,
          color: device.thisDevice ? context.theme.accent : const Color(0xff3c8cff),
        ),
      ),
    );
  }

  Widget _wrapInDismissible(BuildContext context, FamilyDevice d, Widget child) {
    return Slidable(
      key: Key(d.device.alias),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) => showSelectProfileDialog(context, device: d.device),
            backgroundColor: context.theme.textPrimary.withOpacity(0.15),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.profile_circled,
            label: "family stats label profile".i18n,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        _showSlidableActionToUser(Slidable.of(context));
        return child;
      }),
    );
  }

  // To show to user, that the slidable options are available
  _showSlidableActionToUser(SlidableController? ctrl) async {
    if (ctrl == null) return;
    if (await _slidableOnboarding.fetch(Markers.ui) == true) return;
    _slidableOnboarding.change(Markers.ui, true);

    Future.delayed(const Duration(milliseconds: 500), () {
      ctrl.openEndActionPane();
    });

    Future.delayed(const Duration(seconds: 2), () {
      ctrl.close();
    });
  }

  Widget _buildAddDeviceButton(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: MiniCard(
            onTap: () {
              _modal.change(Markers.userTap, Modal.familyLinkDevice);
            },
            color: context.theme.accent,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.plus_circle,
                      size: 28,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "family device header add".i18n,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeBlokadaSixDevicePointer extends StatelessWidget {
  HomeBlokadaSixDevicePointer({
    super.key,
    required this.color,
  });

  final Color color;
  final _stage = Core.get<StageStore>();

  @override
  Widget build(BuildContext context) {
    return MiniCard(
      onTap: Core.act.isIos ? () => _stage.openUrl("six://", Markers.userTap) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeviceCardHeader(
            text: "app settings section header".i18n,
            iconName: "Blokada 6",
            color: color,
            chevronText: Core.act.isIos ? "family device action open six".i18n : null,
            chevronIcon: Core.act.isIos ? Icons.chevron_right : null,
          ),
          const SizedBox(height: 12),
          Text(
            "family device managed by six".i18n,
            style: TextStyle(
              color: context.theme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
