import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstallReferrerData.parse', () {
    test('parses a Google Ads referrer as non-organic', () {
      final d = InstallReferrerData.parse(
          'gclid=ABC123&utm_source=google&utm_medium=cpc'
          '&utm_campaign=summer&utm_content=banner&utm_term=vpn');

      expect(d.gclid, 'ABC123');
      expect(d.utmSource, 'google');
      expect(d.utmMedium, 'cpc');
      expect(d.utmCampaign, 'summer');
      expect(d.utmContent, 'banner');
      expect(d.utmTerm, 'vpn');
      expect(d.isOrganic, isFalse);
      expect(d.rawReferrer, contains('gclid=ABC123'));
    });

    test('parses a Play organic referrer as organic', () {
      final d = InstallReferrerData.parse(
          'utm_source=google-play&utm_medium=organic');

      expect(d.isOrganic, isTrue);
      expect(d.gclid, isNull);
      expect(d.utmSource, 'google-play');
    });

    test('url-decodes values', () {
      final d = InstallReferrerData.parse(
          'utm_campaign=hello%20world&gclid=a%2Bb');

      expect(d.utmCampaign, 'hello world');
      expect(d.gclid, 'a+b');
      expect(d.isOrganic, isFalse);
    });

    test('null/empty referrer is organic with all fields null', () {
      for (final v in [null, '', '   ']) {
        final d = InstallReferrerData.parse(v);
        expect(d.isOrganic, isTrue);
        expect(d.gclid, isNull);
        expect(d.utmSource, isNull);
        expect(d.rawReferrer, isNull);
      }
    });

    test('malformed referrer does not throw and keeps rawReferrer', () {
      final d = InstallReferrerData.parse('&&=foo&utm_source');
      expect(d.rawReferrer, '&&=foo&utm_source');
      expect(d.isOrganic, isTrue); // no gclid, no usable source
    });

    test('any gclid forces non-organic even with google-play source', () {
      final d = InstallReferrerData.parse(
          'utm_source=google-play&gclid=xyz');
      expect(d.isOrganic, isFalse);
    });

    test('utm_medium=paid is treated as non-organic', () {
      final d = InstallReferrerData.parse(
          'utm_source=partner&utm_medium=paid');
      expect(d.isOrganic, isFalse);
    });
  });

  group('InstallReferrerData.toAttributionMap', () {
    test('maps Google Ads fields and omits empty keys', () {
      final map = InstallReferrerData.parse(
              'gclid=g&utm_source=google&utm_medium=cpc'
              '&utm_campaign=summer&utm_content=banner&utm_term=vpn')
          .toAttributionMap();

      expect(map['status'], 'non_organic');
      expect(map['channel'], 'google');
      expect(map['campaign'], 'summer');
      expect(map['ad_set'], 'cpc');
      expect(map['creative'], 'banner');
      expect(map['ad_group'], 'vpn');
    });

    test('organic produces status organic with sane defaults', () {
      final map = InstallReferrerData.parse(null).toAttributionMap();
      expect(map['status'], 'organic');
      expect(map['channel'], 'google-play');
      expect(map['ad_set'], 'organic');
      expect(map.containsKey('campaign'), isFalse);
      expect(map.containsKey('creative'), isFalse);
    });

    test('truncates values to 50 chars', () {
      final long = 'c' * 80;
      final map =
          InstallReferrerData.parse('utm_source=google&utm_campaign=$long')
              .toAttributionMap();
      expect((map['campaign'] as String).length, 50);
    });
  });

  group('InstallReferrerData.buildCustomAttributes', () {
    test('always includes acq_status', () {
      final attrs = InstallReferrerData.parse(null).buildCustomAttributes();
      final status = attrs.firstWhere((a) => a['key'] == 'acq_status');
      expect(status['value'], 'organic');
    });

    test('chunks a long gclid into <=50-char acq_gclid keys', () {
      final gclid = 'x' * 120;
      final attrs =
          InstallReferrerData.parse('gclid=$gclid&utm_medium=cpc')
              .buildCustomAttributes();

      final gclidAttrs =
          attrs.where((a) => (a['key'] as String).startsWith('acq_gclid'));
      expect(gclidAttrs, isNotEmpty);
      for (final a in gclidAttrs) {
        expect((a['key'] as String), matches(r'^[a-zA-Z0-9\-._]+$'));
        expect((a['key'] as String).length, lessThanOrEqualTo(30));
        expect((a['value'] as String).length, lessThanOrEqualTo(50));
      }
      expect(gclidAttrs.any((a) => a['key'] == 'acq_gclid'), isTrue);
      // reconstructed value matches original (capped at 4 chunks => 200 chars,
      // here 120 chars fits fully)
      final joined = gclidAttrs.map((a) => a['value'] as String).join();
      expect(joined, gclid);
    });

    test('no gclid key when gclid absent', () {
      final attrs =
          InstallReferrerData.parse('utm_source=google-play')
              .buildCustomAttributes();
      expect(attrs.any((a) => (a['key'] as String).startsWith('acq_gclid')),
          isFalse);
    });
  });
}
