import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';

part 'actor.dart';
part 'value.dart';

class PermModule with Module {
  @override
  onCreateModule() async {
    await register(DnsPerm());
    await register(PermActor());
    await register<PrivateDnsStringProvider>(FamilyPrivateDnsStringProvider());
  }
}

class FamilyPrivateDnsStringProvider extends PrivateDnsStringProvider {
  late final _actor = Core.get<PermActor>();

  @override
  String getAndroidDnsString() {
    return _actor.getAndroidDnsStringToCopy(Markers.root);
  }
}
