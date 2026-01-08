part of 'api.dart';

class FreemiumDataProvider {
  final _random = math.Random();

  bool shouldMockEndpoint(ApiEndpoint endpoint) {
    return const [
      ApiEndpoint.getStatsV2,
      ApiEndpoint.getJournalV2,
      ApiEndpoint.getLists,
      ApiEndpoint.getDeviceV2,
    ].contains(endpoint);
  }

  String getDataFor(ApiEndpoint endpoint, QueryParams? params) {
    switch (endpoint) {
      case ApiEndpoint.getStatsV2:
        return _getStatsData();
      case ApiEndpoint.getJournalV2:
        return _getJournalData();
      case ApiEndpoint.getLists:
        return _getListsData();
      case ApiEndpoint.getDeviceV2:
        return _getDeviceData();
      default:
        return '{}';
    }
  }

  String _getStatsData() {
    final now = DateTime.now();
    final totalBlocked = (15234 + _random.nextInt(1000)).toString();
    final totalAllowed = (45621 + _random.nextInt(5000)).toString();
    
    final stats = <String, dynamic>{
      'total_blocked': totalBlocked,
      'total_allowed': totalAllowed,
      'stats': {
        'metrics': [
          // Blocked metrics by company
          {
            'tags': {'action': 'blocked', 'company': 'Example Analytics'},
            'dps': _generateTimeSeries(now, 24, 20, 100),
          },
          {
            'tags': {'action': 'blocked', 'company': 'Ad Platform Inc'},
            'dps': _generateTimeSeries(now, 24, 15, 80),
          },
          {
            'tags': {'action': 'blocked', 'company': 'Site Analytics'},
            'dps': _generateTimeSeries(now, 24, 10, 60),
          },
          // Allowed metrics by company
          {
            'tags': {'action': 'allowed', 'company': 'Cloudflare'},
            'dps': _generateTimeSeries(now, 24, 200, 500),
          },
          {
            'tags': {'action': 'allowed', 'company': 'Google'},
            'dps': _generateTimeSeries(now, 24, 100, 300),
          },
          {
            'tags': {'action': 'allowed', 'company': 'GitHub'},
            'dps': _generateTimeSeries(now, 24, 50, 150),
          },
          // Blocked metrics by device
          {
            'tags': {'action': 'blocked', 'device_name': 'iPhone'},
            'dps': _generateTimeSeries(now, 24, 30, 120),
          },
          {
            'tags': {'action': 'blocked', 'device_name': 'iPad'},
            'dps': _generateTimeSeries(now, 24, 20, 80),
          },
          {
            'tags': {'action': 'blocked', 'device_name': 'Android Phone'},
            'dps': _generateTimeSeries(now, 24, 25, 100),
          },
          // Allowed metrics by device
          {
            'tags': {'action': 'allowed', 'device_name': 'iPhone'},
            'dps': _generateTimeSeries(now, 24, 150, 400),
          },
          {
            'tags': {'action': 'allowed', 'device_name': 'iPad'},
            'dps': _generateTimeSeries(now, 24, 100, 300),
          },
          {
            'tags': {'action': 'allowed', 'device_name': 'Android Phone'},
            'dps': _generateTimeSeries(now, 24, 120, 350),
          },
        ]
      }
    };

    return jsonEncode(stats);
  }

  String _getJournalData() {
    final now = DateTime.now();
    final activity = <String, dynamic>{
      'activity': _generateJournalActivity(now, 100),
    };

    return jsonEncode(activity);
  }

  String _getListsData() {
    final lists = <String, dynamic>{
      'lists': [
        {
          'id': 'oisd',
          'name': 'v4/oisd/basic/small',
          'managed': true,
          'is_allowlist': false,
        },
        {
          'id': 'stevenblack',
          'name': 'v4/stevenblack/unified/hosts',
          'managed': true,
          'is_allowlist': false,
        },
        {
          'id': 'goodbyeads',
          'name': 'v4/goodbyeads/standard/big',
          'managed': true,
          'is_allowlist': false,
        },
        {
          'id': 'adaway',
          'name': 'v4/adaway/standard/hosts',
          'managed': true,
          'is_allowlist': false,
        },
        {
          'id': 'phishingarmy',
          'name': 'v4/phishingarmy/standard/extended',
          'managed': true,
          'is_allowlist': false,
        },
        {
          'id': 'ddgtrackerradar',
          'name': 'v4/ddgtrackerradar/tds/standard',
          'managed': true,
          'is_allowlist': false,
        },
      ]
    };

    return jsonEncode(lists);
  }

  String _getDeviceData() {
    // Return consistent device data that matches what DeviceStore expects
    final device = <String, dynamic>{
      'device_tag': '000000',
      'lists': [
        '05ea377c9a64cba97bf8a6f38cb3a7fa',
      ],
      'retention': 'persistent',
      'paused': false,
      'paused_for': 0,
      'safe_search': false,
    };

    return jsonEncode(device);
  }

  List<Map<String, dynamic>> _generateJournalActivity(DateTime now, int count) {
    final activity = <Map<String, dynamic>>[];
    final domains = [
      'tracker.example.com',
      'ads.platform.com',
      'cdn.cloudflare.com',
      'api.github.com',
      'fonts.googleapis.com',
      'analytics.site.com',
      'pixel.tracking.net',
      'metrics.service.io',
      'content.delivery.net',
      'images.unsplash.com',
    ];

    final devices = ['iPhone', 'iPad', 'Android Phone'];
    final lists = ['ads', 'trackers', 'malware', 'allowed'];

    for (int i = 0; i < count; i++) {
      final timestamp = now.subtract(Duration(minutes: i * 5));
      final domain = domains[_random.nextInt(domains.length)];
      final isBlocked = _random.nextBool();

      activity.add({
        'device_name': devices[_random.nextInt(devices.length)],
        'domain_name': domain,
        'action': isBlocked ? 'block' : 'allow',
        'list': isBlocked ? lists[_random.nextInt(3)] : lists[3],
        'profile': _random.nextBool() ? 'default' : null,
        'timestamp': timestamp.toIso8601String(),
      });
    }

    return activity;
  }

  List<Map<String, dynamic>> _generateTimeSeries(DateTime now, int hours, int minValue, int maxValue) {
    final dps = <Map<String, dynamic>>[];
    
    for (int i = hours - 1; i >= 0; i--) {
      final timestamp = now.subtract(Duration(hours: i));
      final value = minValue + _random.nextInt(maxValue - minValue);
      
      dps.add({
        'timestamp': (timestamp.millisecondsSinceEpoch ~/ 1000).toString(),
        'value': value.toString(),
      });
    }
    
    return dps;
  }
}
