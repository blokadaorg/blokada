import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';

/// Serves canned API responses by path, so screens that fetch on open
/// (Privacy Pulse) render real content. Timestamps are relative to now, so
/// labels like "2 minutes ago" and the hourly buckets stay the same every run.
class FakeHttpChannel with HttpChannel {
  String _respond(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    switch (uri.path) {
      case '/v2/stats':
        return _stats(params['since'] ?? '24h');
      case '/v2/activity/toplist':
        return _toplist(params['action'] ?? 'blocked', params['range'] ?? '24h');
      case '/v2/activity':
        // A non-empty start asks for the page before it; there is only one page.
        if ((params['start'] ?? '').isNotEmpty) return jsonEncode({'activity': []});
        return _activity(params['action']);
      case '/v2/customlist':
        return jsonEncode({'customlist': []});
    }
    throw Exception('FakeHttpChannel: no response for ${uri.path}');
  }

  @override
  Future<String> doGet(String url) async => _respond(url);

  @override
  Future<String> doRequest(String url, String? payload, String type) async => _respond(url);

  @override
  Future<String> doRequestWithHeaders(
          String url, String? payload, String type, Map<String?, String?> h) async =>
      _respond(url);
}

final _now = DateTime.now().toUtc();
int get _nowSeconds => _now.millisecondsSinceEpoch ~/ 1000;

// Requests per hour over the last 48 hours, newest last.
const _allowedPerHour = [3, 1, 0, 0, 0, 0, 1, 4, 6, 5, 4, 3, 5, 6, 4, 3, 5, 6, 7, 5, 4, 3, 2, 3];
const _blockedPerHour = [1, 0, 0, 0, 0, 0, 0, 2, 3, 2, 1, 1, 2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 1, 2];

String _stats(String since) {
  final days = since == '1w' ? 7 : (since == '2w' ? 14 : 0);
  final step = days > 0 ? 24 * 3600 : 3600;
  final points = days > 0 ? days : 48;

  List<Map<String, String>> dps(List<int> perHour, int scale) => [
        for (var i = 0; i < points; i++)
          {
            'timestamp': '${_nowSeconds - (points - 1 - i) * step}',
            'value': '${perHour[i % perHour.length] * scale}',
          }
      ];

  final scale = days > 0 ? 60 : 1;
  return jsonEncode({
    'total_allowed': '1840',
    'total_blocked': '412',
    'stats': {
      'metrics': [
        {'tags': {'action': 'allowed'}, 'dps': dps(_allowedPerHour, scale)},
        {'tags': {'action': 'blocked'}, 'dps': dps(_blockedPerHour, scale)},
      ],
    },
  });
}

String _toplist(String action, String range) {
  final entries = action == 'blocked'
      ? {
          'doubleclick.net': 14,
          'google-analytics.com': 9,
          'app-measurement.com': 7,
          'graph.facebook.com': 5,
          'ads.mopub.com': 3,
        }
      : {
          'apple.com': 22,
          'gstatic.com': 17,
          'googleapis.com': 12,
          'icloud.com': 8,
          'github.com': 4,
        };
  return jsonEncode({
    'toplist': [
      {
        'action': action,
        'entries': [
          for (final e in entries.entries) {'name': e.key, 'count': e.value}
        ],
      }
    ],
    'window': {
      'label': range,
      'start': _now.subtract(const Duration(hours: 24)).toIso8601String(),
      'end': _now.toIso8601String(),
    },
    'level': '1',
    'limit': 12,
  });
}

String _activity(String? action) {
  const blocked = ['doubleclick.net', 'app-measurement.com', 'google-analytics.com'];
  const allowed = ['apple.com', 'gstatic.com', 'news.ycombinator.com', 'github.com'];
  final domains = action == 'block' ? blocked : (action == 'allow' ? allowed : [...blocked, ...allowed]);
  return jsonEncode({
    'activity': [
      for (var i = 0; i < domains.length; i++)
        {
          'device_name': 'Pixel',
          'domain_name': domains[i],
          'action': blocked.contains(domains[i]) ? 'block' : 'allow',
          'list': blocked.contains(domains[i]) ? '05ea377c9a64cba97bf8a6f38cb3a7fa' : '',
          'timestamp': _now.subtract(Duration(minutes: 2 + i * 3)).toIso8601String(),
        }
    ],
  });
}
