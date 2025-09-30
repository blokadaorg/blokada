import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:dartx/dartx.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'actor.dart';
part 'api.dart';
part 'model.dart';

class JournalEntriesValue extends Value<List<UiJournalEntry>> {
  JournalEntriesValue() : super(load: () => [], sensitive: true);
}

class JournalFilterValue extends Value<JournalFilter> {
  JournalFilterValue() : super(load: () => _noFilter);

  reset() => now = _noFilter;
}

class JournalDevicesValue extends Value<Set<String>> {
  JournalDevicesValue() : super(load: () => {}, sensitive: true);
}

class JournalModule with Module {
  @override
  onCreateModule() async {
    await register(JournalEntriesValue());
    await register(JournalFilterValue());
    await register(JournalDevicesValue());
    await register(JournalApi());
    await register(JournalActor());
  }
}
