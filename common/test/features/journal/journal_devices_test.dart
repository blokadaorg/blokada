import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

/// Serves the device list route and, for the rows, only the filtered
/// device's entries, as the server does.
class _FakeJournalApi extends Fake implements JournalApi {
  List<String> accountDevices = [];
  Object? devicesError;
  // When set, the device list waits for it, to answer out of order.
  Future<void>? devicesGate;
  // When set, the rows wait for it, to answer after a newer screen opened.
  Future<void>? rowsGate;
  final rows = <JsonJournalEntry>[];

  @override
  Future<List<String>> fetchDevicesForV6(Marker m) async {
    final names = accountDevices;
    final gate = devicesGate;
    if (gate != null) await gate;
    if (devicesError != null) throw devicesError!;
    return names;
  }

  @override
  Future<List<JsonJournalEntry>> fetchForV6(
    Marker m, {
    String? start,
    String? domain,
    String? action,
    String? deviceName,
    int? limit,
  }) async {
    final snapshot = List.of(rows);
    final gate = rowsGate;
    if (gate != null) await gate;
    return snapshot.where((it) => deviceName == null || it.deviceName == deviceName).toList();
  }
}

// Each device gets its own domain: rows for one domain are grouped into one.
JsonJournalEntry _row(String device) => JsonJournalEntry(
      deviceName: device,
      domainName: "${device.toLowerCase().replaceAll(' ', '')}.example.com",
      action: "allow",
      list: "",
      profile: null,
      timestamp: DateTime.utc(2026, 1, 1).toIso8601String(),
    );

void main() {
  group('device filter list', () {
    late _FakeJournalApi api;
    late JournalActor journal;

    void register() {
      api = _FakeJournalApi();
      Core.register<JournalApi>(api);
      Core.register<CustomListsValue>(CustomListsValue());
      Core.register<JournalEntriesValue>(JournalEntriesValue());
      Core.register<JournalFilterValue>(JournalFilterValue());
      Core.register<JournalDevicesValue>(JournalDevicesValue());
      journal = JournalActor();
    }

    void filterBy(String device) {
      final filter = Core.get<JournalFilterValue>();
      filter.now = filter.now.updateOnly(deviceName: device);
    }

    Set<String> devices() => Core.get<JournalDevicesValue>().now;

    test('a device filter keeps the account devices', () async {
      await withTrace((m) async {
        register();
        api.accountDevices = ["Router", "iPhone", "iPad"];
        api.rows.addAll([_row("iPhone"), _row("Router")]);
        filterBy("iPhone");

        await journal.loadDevices(m);
        await journal.fetch(m);
        expect(devices(), {"iPad", "iPhone", "Router"});

        filterBy("Router");
        await journal.fetch(m);
        expect(devices(), {"iPad", "iPhone", "Router"});
      });
    });

    test('devices in the rows and the filtered device are listed', () async {
      await withTrace((m) async {
        register();
        api.accountDevices = ["Router"];
        api.rows.add(_row("Laptop"));
        filterBy("Quiet phone");

        await journal.loadDevices(m);
        await journal.fetch(m);
        // Listed while it is the filter; it has no recent activity.
        expect(devices(), {"Quiet phone", "Router"});

        filterBy("");
        await journal.fetch(m);
        expect(devices(), {"Laptop", "Router"});
      });
    });

    test('a failed device list falls back to the rows', () async {
      await withTrace((m) async {
        register();
        api.devicesError = Exception("not found");
        api.rows.addAll([_row("iPhone"), _row("Router")]);

        await journal.loadDevices(m);
        await journal.fetch(m);
        expect(devices(), {"iPhone", "Router"});
      });
    });

    test('a new screen starts the list afresh', () async {
      await withTrace((m) async {
        register();
        api.accountDevices = ["Old name"];
        await journal.loadDevices(m);
        expect(devices(), {"Old name"});

        api.accountDevices = ["New name"];
        await journal.loadDevices(m);
        expect(devices(), {"New name"});
      });
    });

    test('a slow list from an earlier screen does not replace a later one', () async {
      await withTrace((m) async {
        register();
        final gate = Completer<void>();
        api.accountDevices = ["Old name"];
        api.devicesGate = gate.future;
        final first = journal.loadDevices(m);

        api.accountDevices = ["New name"];
        api.devicesGate = null;
        await journal.loadDevices(m);
        gate.complete();
        await first;
        expect(devices(), {"New name"});
      });
    });

    test('rows from an earlier screen do not reach a later one', () async {
      await withTrace((m) async {
        register();
        await journal.loadDevices(m);
        final gate = Completer<void>();
        api.rows.add(_row("Old name"));
        api.rowsGate = gate.future;
        final first = journal.fetch(m);

        api.rowsGate = null;
        api.rows.clear();
        api.accountDevices = ["New name"];
        await journal.loadDevices(m);
        gate.complete();
        await first;
        expect(devices(), {"New name"});
        expect(Core.get<JournalEntriesValue>().now, isEmpty);
      });
    });

    test('a refresh keeps the devices in the rows', () async {
      await withTrace((m) async {
        register();
        api.rows.add(_row("Row device"));
        await journal.loadDevices(m);
        await journal.fetch(m);

        // A page still loading when the refresh starts adds its devices too.
        final rowsGate = Completer<void>();
        api.rows.add(_row("Next page device"));
        api.rowsGate = rowsGate.future;
        final more = journal.fetch(m);

        final devicesGate = Completer<void>();
        api.accountDevices = ["Account device"];
        api.devicesGate = devicesGate.future;
        final refresh = journal.refreshDevices(m);
        expect(devices(), {"Row device"});

        rowsGate.complete();
        await more;
        devicesGate.complete();
        await refresh;
        expect(devices(), {"Account device", "Next page device", "Row device"});
      });
    });

    test('a padded name in the rows is listed once', () async {
      await withTrace((m) async {
        register();
        api.accountDevices = ["iPhone"];
        api.rows.add(_row("iPhone "));

        await journal.loadDevices(m);
        await journal.fetch(m);
        expect(devices(), {"iPhone"});
      });
    });
  });
}
