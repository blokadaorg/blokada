import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/plus/lease/channel.pg.dart';
import 'package:common/platform/plus/lease/lease.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class VpnDevicesSection extends StatefulWidget {
  final bool primary;

  const VpnDevicesSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => VpnDevicesSectionState();
}

class VpnDevicesSectionState extends State<VpnDevicesSection> with Logging {
  late final _plusLease = Core.get<PlusLeaseStore>();

  List<Lease> _leases = [];
  Lease? _currentLease;

  @override
  void initState() {
    super.initState();
    reactionOnStore((_) => _plusLease.leaseChanges, (_) {
      _reload();
    });
    reactionOnStore((_) => _plusLease.currentLease, (_) {
      _reload();
    });
    _reload();
  }

  _reload() {
    setState(() {
      _leases = _plusLease.leases;
      _currentLease = _plusLease.currentLease;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          primary: widget.primary,
          children: [
            SizedBox(height: getTopPadding(context)),
            CommonCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Text("account lease label devices list".i18n,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: context.theme.textSecondary))),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 24.0, bottom: 12),
              child: Text("account lease label devices".i18n,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            CommonCard(
                padding: const EdgeInsets.all(0),
                child: _buildDevices(context)),
          ],
        ));
  }

  Widget _buildDevices(BuildContext context) {
    //   final widgets = [
    //     _wrapInDismissible(
    //         context,
    //         "abc",
    //         _buildDevice(
    //           context,
    //           name: "iPhone",
    //           thisDevice: true,
    //         )),
    //     _wrapInDismissible(
    //         context,
    //         "oo",
    //         _buildDevice(
    //           context,
    //           name: "823h2t3h242gcgh3",
    //           thisDevice: false,
    //         )),
    //   ];
    // return Column(children: widgets);

    if (_leases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18.0),
        child: Text(
          "universal label none".i18n,
          style: Theme.of(context)
              .textTheme
              .bodyLarge!
              .copyWith(color: context.theme.textSecondary),
        ),
      );
    }

    return Column(
      children: _leases.map((lease) {
        return _wrapInDismissible(
            context,
            lease.publicKey,
            _buildDevice(
              context,
              name: lease.alias ?? lease.publicKey.short(),
              thisDevice: lease == _currentLease,
            ));
      }).toList(),
    );
  }

  Widget _buildDevice(BuildContext context,
      {required String name, required bool thisDevice}) {
    final suffix = thisDevice ? "account lease label this device".i18n : "";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(name + suffix,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          Icon(Icons.devices, color: context.theme.textSecondary),
        ],
      ),
    );
  }

  Widget _wrapInDismissible(
      BuildContext context, String publicKey, Widget child) {
    return Slidable(
      key: Key(publicKey),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) => deleteLease(context, publicKey),
            backgroundColor: Colors.red.withOpacity(0.95),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: "universal action delete".i18n,
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
        ],
      ),
      child: child,
    );
  }

  deleteLease(BuildContext context, String publicKey) {
    _plusLease.deleteLeaseById(publicKey, Markers.userTap);
  }
}
