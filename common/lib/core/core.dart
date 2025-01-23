import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

part 'act.dart';
part 'actor.dart';
part 'async.dart';
part 'command.dart';
part 'config.dart';
part 'di.dart';
part 'emitter.dart';
part 'i18n.dart';
part 'json.dart';
part 'list_extensions.dart';
part 'logger/logger.dart';
part 'logger/marker.dart';
part 'logger/output.dart';
part 'logger/trace.dart';
part 'module.dart';
part 'persistence/persistence.dart';
part 'persistence/value.dart';
part 'platform_info.dart';
part 'scheduler.dart';
part 'value.dart';
part 'widget.dart';

// A simple annotation to mark what interfaces are not fulfilled by the module
// but has to be provided by the platform modules.
class PlatformProvided {
  const PlatformProvided();
}

class CoreModule with Module {
  @override
  onCreateModule() async {
    await register(Scheduler(timer: SchedulerTimer()));

    await register(Persistence(isSecure: false));
    await register(Persistence(isSecure: true), tag: Persistence.secure);
  }
}
