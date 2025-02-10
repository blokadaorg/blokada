import 'package:collection/collection.dart';
import 'package:common/common/module/env/env.dart';
import 'package:common/common/module/lock/lock.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/platform/account/account.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'model.dart';

@PlatformProvided()
mixin LinkChannel {
  Future<void> doLinksChanged(Map<LinkId, String> links);
}

class LinkModule with Module {
  @override
  onCreateModule() async {
    await register(LinkActor());
  }
}
