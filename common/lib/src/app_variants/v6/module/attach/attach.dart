import 'dart:convert';

import 'package:common/src/app_variants/v6/widget/attach_sheet.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/config/domain/config.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/stage/stage.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';

/// Lets the user protect another device (a laptop, a second phone) without
/// handing over their account ID.
///
/// The backend mints a single-use hand-off token; the app turns it into a
/// dashboard link and either opens it here or shares it. Whoever opens the
/// link once is signed in on that device. Nothing about the flow is
/// persisted: tokens die after one use or five minutes.
class AttachModule with Module {
  @override
  onCreateModule() async {
    await register(AttachApi());
    await register(AttachActor());
  }
}
