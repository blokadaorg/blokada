import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/auth/api.dart';
import 'package:common/dragon/device/current_token.dart';
import 'package:common/logger/logger.dart';
import 'package:common/scheduler/scheduler.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';

const _keyRefresh = "authRefreshToken";
const _keyHeartbeat = "authHeartbeat";
const _frequencyHeartbeat = Duration(minutes: 30);

class AuthController with Logging {
  late final _api = dep<AuthApi>();
  late final _accountId = dep<AccountId>();
  late final _currentToken = dep<CurrentToken>();
  late final _scheduler = dep<Scheduler>();
  late final _stage = dep<StageStore>();

  Function(Marker) onTokenRefreshed = (m) {};
  Function(Marker) onTokenExpired = (m) {};

  start(Marker m) async {
    await _recheckToken(m);
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;
    _recheckToken(m);
  }

  _recheckToken(Marker m) async {
    final token = await _currentToken.fetch();
    if (token != null) {
      log(Markers.auth).i("current token is $token");
      try {
        useToken(token, m);
        startHeartbeat();
      } catch (_) {}
    }
  }

  Future<DeviceTag> useToken(String token, Marker m) async {
    final payload = await _startMonitoringTokenExpiry(token, m);
    _currentToken.now = token;
    return payload.deviceTag;
  }

  Future<String> createToken(DeviceTag deviceTag, Marker m) async {
    final payload = await _api.auth(_accountId.now, deviceTag, m);
    return payload.token!;
  }

  Future<JsonAuthEndpoint> getToken(String token, Marker m) async {
    return await _api.getInfo(token, m);
  }

  Future<JsonAuthEndpoint> _startMonitoringTokenExpiry(
      String token, Marker m) async {
    try {
      final payload = await getToken(token, m);
      if (payload.isExpired) {
        onTokenExpired(m);
        throw Exception("Token is already expired");
      } else {
        onTokenRefreshed(m);
        await _scheduler.addOrUpdate(Job(
          _keyRefresh,
          Markers.auth,
          before: payload.expiry.subtract(const Duration(minutes: 5)),
          when: [Condition(Event.appForeground, value: "1")],
          callback: _refreshToken,
        ));
        return payload;
      }
    } catch (e) {
      onTokenExpired(m);
      throw Exception("Failed to get token info: $e");
    }
  }

  Future<bool> _refreshToken(Marker m) async {
    try {
      final token = _currentToken.now;
      if (token == null) return false;
      final payload = await _api.refresh(token, m);
      _currentToken.now = payload.token;
      onTokenRefreshed(m);
      return true;
    } catch (e) {
      onTokenExpired(m); // TODO: may be too aggressive
      _currentToken.now = null;
      throw Exception("Failed to refresh token: $e");
    }
  }

  startHeartbeat() async {
    final token = _currentToken.now;
    if (token == null) return;
    await _scheduler.addOrUpdate(
        Job(
          _keyHeartbeat,
          Markers.auth,
          every: _frequencyHeartbeat,
          when: [Condition(Event.appForeground, value: "1")],
          callback: (m) async => await _doHeartbeat(token, m),
        ),
        immediate: true);
  }

  Future<bool> _doHeartbeat(String token, Marker m) async {
    try {
      log(m).i("sending heartbeat");
      await _api.sendHeartbeat(token, m);
      return true;
    } on HttpCodeException catch (e) {
      if (e.code == 401) {
        onTokenExpired(m);
        _currentToken.now = null;
        await _scheduler.stop(_keyHeartbeat);
        log(m).w("token unavailable, stopping heartbeat");
        throw SchedulerException(e);
      } else {
        log(m).e(msg: "failed to send heartbeat", err: e);
        throw SchedulerException(e, canRetry: true);
      }
    } catch (e) {
      log(m).e(msg: "failed to send heartbeat", err: e);
      throw SchedulerException(e, canRetry: true);
    }
  }
}
