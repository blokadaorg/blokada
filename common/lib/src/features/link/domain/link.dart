import 'package:collection/collection.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/platform/account/account.dart';
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
