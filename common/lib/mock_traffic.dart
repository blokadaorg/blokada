import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// Mocked-only ambient traffic generator. Fires DoH queries straight at the
// device's cloud.blokada.org DoH endpoint so the dev account's stats
// pipeline records real queries and Privacy Pulse / Activity render with a
// natural-looking 24h histogram and toplist. Without this the screens stay
// on "waiting for data" because the simulator's OS DNS isn't routed through
// Blokada (PrivateDnsService is mocked).
//
// Bypasses HttpChannel and uses package:http directly: that channel
// serializes payloads via String.utf8 and only accepts 200, neither of
// which fits a binary DNS wire-format request. Acceptable because this
// module only runs under Core.act.isMocked.
class MockTrafficGenerator {
  // Returns the set of per-device DoH endpoints to POST queries to, empty if
  // no device tag is resolved yet. Callers build the flavor-specific paths:
  // family fans out across every known device tag (/{tag} per linked kid plus
  // the parent's own), v6 is a single /{tag}/{alias-escaped}. The resolver
  // associates queries with a device by parsing the path. Re-read every loop
  // so devices linked/unlinked at runtime are picked up without a restart.
  final List<Uri> Function() _resolveEndpoints;

  final Random _rnd = Random();
  bool _started = false;

  MockTrafficGenerator(this._resolveEndpoints);

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_runBurstLoop());
  }

  // Real DNS traffic isn't uniform: a page load fans out a burst of
  // queries clustered in seconds, then the device idles. Mimic that so the
  // 24h histogram in stats UI doesn't look like a metronome. Each burst is
  // attributed to one randomly-picked device, so in family every linked kid
  // row populates over time rather than only the parent's own device.
  Future<void> _runBurstLoop() async {
    while (true) {
      final endpoints = _resolveEndpoints();
      if (endpoints.isEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      final endpoint = endpoints[_rnd.nextInt(endpoints.length)];
      final burstSize = 3 + _rnd.nextInt(13); // 3..15
      for (var i = 0; i < burstSize; i++) {
        unawaited(_fireOne(endpoint, _pickDomain()));
        await Future.delayed(Duration(milliseconds: 50 + _rnd.nextInt(400)));
      }
      await Future.delayed(Duration(seconds: 20 + _rnd.nextInt(160))); // 20s..3min
    }
  }

  String _pickDomain() {
    final pool = _rnd.nextDouble() < 0.25 ? _blockedPool : _allowedPool;
    return pool[_rnd.nextInt(pool.length)];
  }

  Future<void> _fireOne(Uri endpoint, String domain) async {
    try {
      await http.post(
        endpoint,
        headers: const {'Content-Type': 'application/dns-message'},
        body: _buildDohQuery(domain),
      );
    } catch (_) {
      // Best-effort dev tool. Network blips, simulator offline, resolver
      // 5xx — none of it should ever surface in the UI.
    }
  }
}

Uint8List _buildDohQuery(String domain) {
  final b = BytesBuilder();
  // Header: id=0, flags=0x0100 (standard query, RD=1), QDCOUNT=1, others=0.
  // Resolver ignores the id on DoH, so a fixed zero is fine.
  b.add(const [0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in domain.split('.')) {
    final bytes = utf8.encode(label);
    b.addByte(bytes.length);
    b.add(bytes);
  }
  b.addByte(0); // root label
  b.add(const [0, 1, 0, 1]); // QTYPE=A, QCLASS=IN
  return b.toBytes();
}

// Domains verified against landing-github-pages/mirror/v5/oisd/small (v6
// default) and d3host/standard (family default) on 2026-05-22. Categorical
// picks (ad/analytics/attribution SDK endpoints) so the set is stable as
// the lists evolve. If the natural-probability of blocked drifts, re-check
// these against the same two lists.
const _blockedPool = [
  // d3host/standard — apex blocked, so every subdomain hits
  'chartboost.com',
  'criteo.com',
  'googlesyndication.com',
  'unityads.unity3d.com',
  // oisd/small — specific subdomains
  'adm.hotjar.com',
  'api.mixpanel.com',
  'decide.mixpanel.com',
  'api.appsflyer.com',
  'attr.appsflyer.com',
  'api2.branch.io',
  'census-app.scorecardresearch.com',
  'doubleclick.de',
];

const _allowedPool = [
  'apple.com',
  'icloud.com',
  'gstatic.com',
  'wikipedia.org',
  'github.com',
  'cloudflare.com',
  'reddit.com',
  'news.ycombinator.com',
  'nytimes.com',
  'bbc.co.uk',
  'spotify.com',
  'youtube.com',
  'stackoverflow.com',
  'mozilla.org',
  'archlinux.org',
  'cnn.com',
  'amazonaws.com',
  'shopify.com',
  'discord.com',
  'twitch.tv',
  'imgur.com',
  'medium.com',
  'duckduckgo.com',
];
