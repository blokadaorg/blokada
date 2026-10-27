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
  final rows = <JsonJournalEntry>[];

  @override
  Future<List<String>> fetchDevicesForV6(Marker m) async {
    if (devicesError != null) throw devicesError!;
    return accountDevices;
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
    return rows.where((it) => deviceName == null || it.deviceName == deviceName).toList();
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

    void setUp() {
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
        setUp();
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
        setUp();
        api.accountDevices = ["Router"];
        api.rows.add(_row("Laptop"));
        filterBy("Quiet phone");

        await journal.loadDevices(m);
        await journal.fetch(m);
        expect(devices(), {"Quiet phone", "Router"});

        // Listed while it is the filter; it has no recent activity.
        filterBy("");
        await journal.fetch(m);
        expect(devices(), {"Laptop", "Router"});
      });
    });

    test('a failed device list falls back to the rows', () async {
      await withTrace((m) async {
        setUp();
        api.devicesError = Exception("not found");
        api.rows.addAll([_row("iPhone"), _row("Router")]);

        await journal.loadDevices(m);
        await journal.fetch(m);
        expect(devices(), {"iPhone", "Router"});
      });
    });

    test('a new screen starts the list afresh', () async {
      await withTrace((m) async {
        setUp();
        api.accountDevices = ["Old name"];
        await journal.loadDevices(m);
        expect(devices(), {"Old name"});

        api.accountDevices = ["New name"];
        await journal.loadDevices(m);
        expect(devices(), {"New name"});
      });
    });
  });
}
