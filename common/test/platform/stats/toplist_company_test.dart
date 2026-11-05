import 'package:common/src/platform/stats/api.dart' as api;
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _response(List<Map<String, dynamic>> entries) => {
  'toplist': [
    {'action': 'blocked', 'entries': entries},
  ],
  'window': {'label': '24h', 'start': '2026-01-01T00:00:00Z', 'end': '2026-01-02T00:00:00Z'},
  'level': '1',
  'limit': 12,
};

api.JsonToplistEntry _parse(Map<String, dynamic> entry) =>
    api.JsonToplistV2Response.fromJson(_response([entry])).toplist.single.entries.single;

void main() {
  group('JsonToplistEntry', () {
    test('parses an entry without company or category', () {
      final entry = _parse({'name': 'example.com', 'count': 5});

      expect(entry.name, 'example.com');
      expect(entry.count, 5);
      expect(entry.company, isNull);
      expect(entry.category, isNull);
      expect(entry.toJson().containsKey('company'), isFalse);
    });

    test('parses the server company and category', () {
      final entry = _parse({
        'name': 'doubleclick.net',
        'count': 9,
        'company': {'id': 'acme', 'name': 'Acme Ads', 'logo_domain': 'acme.example'},
        'category': 'advertising',
      });

      expect(entry.company!.id, 'acme');
      expect(entry.company!.name, 'Acme Ads');
      expect(entry.company!.logoDomain, 'acme.example');
      expect(entry.category, 'advertising');
      expect(entry.toJson()['company'], {
        'id': 'acme',
        'name': 'Acme Ads',
        'logo_domain': 'acme.example',
      });
    });

    test('tolerates null, partial and mistyped company fields', () {
      expect(
        _parse({'name': 'a.com', 'count': 1, 'company': null, 'category': null}).company,
        isNull,
      );
      expect(_parse({'name': 'a.com', 'count': 1, 'company': 'Acme'}).company, isNull);
      expect(_parse({'name': 'a.com', 'count': 1, 'category': 3}).category, isNull);

      final partial = _parse({
        'name': 'a.com',
        'count': 1,
        'company': {'id': 'acme', 'name': null, 'logo_domain': 7},
      });
      expect(partial.company!.id, 'acme');
      expect(partial.company!.name, isNull);
      expect(partial.company!.logoDomain, isNull);
    });
  });

  group('UiToplistEntry.fromV2', () {
    test('without company it shows and keys on the domain', () {
      final e = UiToplistEntry.fromV2(_parse({'name': 'example.com', 'count': 5}), blocked: true);

      expect(e.company, isNull);
      expect(e.tld, 'example.com');
      expect(e.domain, 'example.com');
      expect(e.displayName, 'example.com');
      expect(e.blocked, isTrue);
      expect(e.value, 5);
    });

    test('with company it shows the name but keys on the domain', () {
      final e = UiToplistEntry.fromV2(
        _parse({
          'name': 'doubleclick.net',
          'count': 9,
          'company': {'id': 'acme', 'name': 'Acme Ads', 'logo_domain': 'acme.example'},
        }),
        blocked: true,
      );

      expect(e.company, 'Acme Ads');
      expect(e.domain, 'doubleclick.net');
      expect(e.displayName, 'Acme Ads');
    });

    test('a blank company name falls back to the domain', () {
      final e = UiToplistEntry.fromV2(
        _parse({
          'name': 'example.com',
          'count': 1,
          'company': {'id': 'x', 'name': '  '},
        }),
        blocked: false,
      );

      expect(e.company, isNull);
      expect(e.displayName, 'example.com');
    });
  });

  group('mergeToplistEntriesByDomain', () {
    test('sums by domain, not by company, and keeps the company name', () {
      final merged = mergeToplistEntriesByDomain([
        UiToplistEntry(null, 'example.com', false, 3),
        UiToplistEntry('Acme', 'acme.example', false, 4),
        UiToplistEntry('Acme', 'acme-cdn.example', false, 1),
        UiToplistEntry(null, 'acme.example', false, 2),
        UiToplistEntry('Example Co', 'example.com', false, 1),
      ]);

      expect(merged.map((e) => e.domain).toList(), [
        'acme.example',
        'example.com',
        'acme-cdn.example',
      ]);
      expect(merged.map((e) => e.value).toList(), [6, 4, 1]);
      expect(merged.map((e) => e.company).toList(), ['Acme', 'Example Co', 'Acme']);
    });
  });

  test('mergeToplistEntriesByDomain merges case variants of one domain', () {
    final merged = mergeToplistEntriesByDomain([
      UiToplistEntry(null, 'Example.COM', false, 2),
      UiToplistEntry(null, 'example.com', false, 3),
    ]);

    expect(merged.single.value, 5);
  });

  group('computeToplistDeltas', () {
    test('matches by domain when the server starts sending company names', () {
      // Previous window from before the server joined companies.
      final previous = [
        UiToplistEntry(null, 'b.example', true, 10),
        UiToplistEntry(null, 'a.example', true, 5),
        UiToplistEntry(null, 'c.example', true, 1),
      ];
      // Two domains of one company: must not collapse or reset.
      final current = [
        UiToplistEntry('Acme', 'a.example', true, 10),
        UiToplistEntry('Acme', 'b.example', true, 5),
        UiToplistEntry(null, 'c.example', true, 1),
        UiToplistEntry('Other', 'd.example', true, 1),
      ];

      final deltas = computeToplistDeltas(current: current, previous: previous, blocked: true);

      expect(deltas.map((d) => d.name).toList(), [
        'a.example',
        'b.example',
        'c.example',
        'd.example',
      ]);
      expect(deltas.map((d) => d.type).toList(), [
        ToplistDeltaType.up,
        ToplistDeltaType.down,
        ToplistDeltaType.same,
        ToplistDeltaType.newEntry,
      ]);
      expect(deltas.map((d) => d.previousRank).toList(), [2, 1, 3, null]);
    });

    test('marks every entry new without a previous window', () {
      final deltas = computeToplistDeltas(
        current: [UiToplistEntry('Acme', 'a.example', false, 1)],
        previous: null,
        blocked: false,
      );

      expect(deltas.single.name, 'a.example');
      expect(deltas.single.type, ToplistDeltaType.newEntry);
    });
  });
}
