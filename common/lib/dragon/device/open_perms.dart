import 'package:common/perm/channel.pg.dart';
import 'package:common/util/di.dart';

class OpenPerms {
  late final _ops = dep<PermOps>();

  open() async {
    _ops.doOpenSettings();
  }
}
