import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/profile/profile_button.dart';
import 'package:common/plus/module/lease/lease.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class VpnDevicesList extends StatefulWidget {
  const VpnDevicesList({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => VpnDevicesListState();
}

class VpnDevicesListState extends State<VpnDevicesList> with Disposables {
  late final _currentLease = Core.get<CurrentLeaseValue>();
  late final _leases = Core.get<LeasesValue>();
  late final _leaseActor = Core.get<LeaseActor>();

  @override
  void initState() {
    super.initState();
    disposeLater(_currentLease.onChange.listen(rebuild));
    disposeLater(_leases.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    super.dispose();
    disposeAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_leases.present!.isEmpty) {
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

    return SlidableAutoCloseBehavior(
      child: Column(
        children: _leases.present!.map((lease) {
          final thisDevice = lease == _currentLease.present;
          final name = lease.alias ?? lease.publicKey.short();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: thisDevice
                ? _buildThisDevice(context, name)
                : _wrapInDismissible(
                    context,
                    lease.publicKey,
                    (context) => _buildDevice(
                          context,
                          name,
                          lease.publicKey,
                        )),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDevice(BuildContext context, String name, String publicKey) {
    return ProfileButton(
      onTap: () {
        Slidable.of(context)?.openEndActionPane();
      },
      icon: Icons.devices,
      iconColor: context.theme.accent,
      name: name,
      trailing: CommonClickable(
        onTap: () {
          Slidable.of(context)?.openEndActionPane();
        },
        padding: const EdgeInsets.all(16),
        child: Icon(
          CupertinoIcons.chevron_forward,
          size: 16,
          color: context.theme.textSecondary,
        ),
      ),
      tapBgColor: context.theme.divider.withOpacity(0.1),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    );
  }

  Widget _buildThisDevice(BuildContext context, String name) {
    return Opacity(
      opacity: 0.7,
      child: ProfileButton(
        onTap: () {},
        icon: Icons.devices,
        iconColor: context.theme.accent,
        name: "family label this device".i18n.withParams(name),
        trailing: CommonClickable(
          onTap: () {},
          padding: const EdgeInsets.all(16),
          child: const SizedBox(height: 16),
        ),
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      ),
    );
  }

  Widget _wrapInDismissible(
      BuildContext context, String publicKey, WidgetBuilder child) {
    return Slidable(
      key: Key(publicKey),
      groupTag: '0',
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
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        return child(context);
      }),
    );
  }

  deleteLease(BuildContext context, String publicKey) {
    _leaseActor.deleteLeaseById(publicKey, Markers.userTap);
  }
}
