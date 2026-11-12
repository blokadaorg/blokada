import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:common/src/features/api/domain/api.dart' as api;
import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'adapty.dart';
part 'adapty_key.dart';
part 'attribute_converter.dart';
part 'api.dart';
part 'channel.dart';
part 'mock_channel.dart';
part 'paywall_sheet.dart';

class PaymentModule with Module {
  @override
  onCreateModule() async {
    await register(PaymentActor());
    await register(PaymentApi());
    await register(PaymentCommand());
    await register(AdaptyApiKey());
  }
}
