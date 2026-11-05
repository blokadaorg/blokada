import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/app/app.dart';

/// Anonymous funnel signals. Each one only adds one to a daily total on the
/// api, and carries exactly the step, the flavor, the platform and the app
/// version: no account ID, device ID or user agent (see the privacy policy).
enum FunnelEvent {
  // Onboarding and setup are counted once per install, so the counts read
  // as installs that reached each step.
  onboardingIntro("onboarding_intro", once: true, arms: true),
  onboardingFamilyHome("onboarding_family_home", once: true, arms: true),
  onboardingDns("onboarding_dns", once: true),
  onboardingSafari("onboarding_safari", once: true),
  setupStarted("setup_started", once: true),
  // Only after this install showed a first-run screen, so installs that were
  // set up before the update don't all count on their next start.
  setupComplete("setup_complete", once: true, needsArmed: true),
  // Every open counts.
  pulseOpenedHome("pulse_opened_home"),
  pulseOpenedPush("pulse_opened_push");

  final String wire;
  final bool once;
  final bool arms;
  final bool needsArmed;

  const FunnelEvent(this.wire, {this.once = false, this.arms = false, this.needsArmed = false});
}

/// The once-per-install events this install already sent. Local only.
class FunnelSentValue extends StringifiedPersistedValue<Set<String>> {
  FunnelSentValue() : super("funnel:sent");

  @override
  Set<String> fromStringified(String value) =>
      value.split(",").where((it) => it.isNotEmpty).toSet();

  @override
  String toStringified(Set<String> value) => (value.toList()..sort()).join(",");
}

/// Sends a signal body to a URL. Throws on a non-200 answer.
abstract class FunnelTransport {
  Future<void> post(String url, String body);
}

/// Posts with dart:io instead of the app's HttpChannel: the native clients
/// stamp every request with the full user agent (OS version, device brand
/// and model), which the funnel must not send. This request carries only
/// Host, Content-Type, Content-Length and Accept-Encoding.
class DirectFunnelTransport implements FunnelTransport {
  @override
  Future<void> post(String url, String body) async {
    final client = HttpClient()
      ..userAgent = null
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.followRedirects = false;
      req.headers.contentType = ContentType.json;
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 15));
      // Bounded too: a stalled body would otherwise hold the client open.
      await res.drain<void>().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw HttpCodeException(res.statusCode, "funnel: ${res.statusCode}");
      }
    } finally {
      client.close(force: true);
    }
  }
}

class FunnelActor with Logging, Actor {
  late final _sent = Core.get<FunnelSentValue>();
  late final _transport = Core.get<FunnelTransport>();
  late final _baseUrl = Core.get<BaseUrl>();
  late final _env = Core.get<EnvActor>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _app = Core.get<AppStore>();

  /// Store builds only; dev and debug builds would skew the totals.
  final bool enabled;

  FunnelActor({bool? enabled}) : enabled = enabled ?? (Core.act.isProd && Core.act.isRelease);

  Future<Set<String>>? _loading;

  @override
  onStart(Marker m) async {
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardPrivateDns) {
        unawaited(send(it.m, FunnelEvent.onboardingDns));
      } else if (it.now == Modal.onboardSafari) {
        unawaited(send(it.m, FunnelEvent.onboardingSafari));
      }
    });

    // Family reports setup complete from its phase, which knows linked
    // devices; Blokada 6 is set up once protection is on.
    if (!Core.act.isFamily) {
      _app.addOn(appStatusChanged, _onAppStatus);
    }
  }

  Future<void> _onAppStatus(Marker m) async {
    if (_app.status.isActive()) {
      await send(m, FunnelEvent.setupComplete);
    }
  }

  /// Fire and forget: never throws, never retries and doesn't wait for the
  /// network. A once-per-install event is marked sent before it goes out, so
  /// a failed send is lost rather than counted twice.
  Future<void> send(Marker m, FunnelEvent event) async {
    if (!enabled) return;
    try {
      if (event.once) {
        final sent = await (_loading ??= _load(m));
        // No await between the check and the add: concurrent calls for the
        // same event can't both pass.
        if (sent.contains(event.wire)) return;
        if (event.needsArmed && !FunnelEvent.values.any((e) => e.arms && sent.contains(e.wire))) {
          return;
        }
        sent.add(event.wire);
        await _sent.change(m, Set.of(sent));
      }
      unawaited(_post(m, event));
    } catch (e, s) {
      log(m).e(msg: "Funnel: could not send ${event.wire}", err: e, stack: s);
    }
  }

  Future<Set<String>> _load(Marker m) async => Set.of(await _sent.fetch(m) ?? <String>{});

  Future<void> _post(Marker m, FunnelEvent event) async {
    try {
      await _transport.post("${_baseUrl.now}v2/funnel", body(event));
      log(m).i("Funnel: sent ${event.wire}");
    } catch (e) {
      log(m).w("Funnel: ${event.wire} not sent: $e");
    }
  }

  /// The whole request body; the api refuses any other field.
  String body(FunnelEvent event) => jsonEncode({
    "event": event.wire,
    "flavor": Core.act.isFamily ? "family" : "six",
    "platform": Core.act.isIos ? "ios" : "android",
    "app_version": _env.appVersion,
  });
}

/// Sends a funnel signal without waiting for it. A no-op where the funnel is
/// not registered (tests, previews), so a signal can never break a feature.
void funnelSignal(Marker m, FunnelEvent event) {
  if (!Core.di.isRegistered<FunnelActor>(instanceName: "default")) return;
  unawaited(Core.get<FunnelActor>().send(m, event));
}

class FunnelModule with Module {
  @override
  onCreateModule() async {
    await register(FunnelSentValue());
    await register<FunnelTransport>(DirectFunnelTransport());
    await register(FunnelActor());
  }
}
