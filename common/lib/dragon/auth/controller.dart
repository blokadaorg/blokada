import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/auth/api.dart';
import 'package:common/dragon/device/current_token.dart';
import 'package:common/dragon/scheduler.dart';
import 'package:common/util/di.dart';

const _keyRefresh = "authRefreshToken";
const _keyHeartbeat = "authHeartbeat";
const _frequencyHeartbeat = Duration(minutes: 30);

class AuthController {
  late final _api = dep<AuthApi>();
  late final _accountId = dep<AccountId>();
  late final _currentToken = dep<CurrentToken>();
  late final _scheduler = dep<Scheduler>();

  Function() onTokenRefreshed = () {};
  Function() onTokenExpired = () {};

  start() async {
    final token = await _currentToken.fetch();
    if (token != null) {
      print("current token is $token");
      try {
        useToken(token);
      } catch (_) {}
    }
  }

  Future<DeviceTag> useToken(String token) async {
    final payload = await _startMonitoringTokenExpiry(token);
    _currentToken.now = token;
    _startHeartbeat();
    return payload.deviceTag;
  }

  Future<String> createToken(DeviceTag deviceTag) async {
    final payload = await _api.auth(_accountId.now, deviceTag);
    return payload.token!;
  }

  Future<JsonAuthEndpoint> getToken(String token) async {
    return await _api.getInfo(token);
  }

  Future<JsonAuthEndpoint> _startMonitoringTokenExpiry(String token) async {
    try {
      final payload = await getToken(token);
      if (payload.isExpired) {
        onTokenExpired();
        throw Exception("Token is already expired");
      } else {
        onTokenRefreshed();
        _scheduler.addOrUpdate(Job(
          _keyRefresh,
          before: payload.expiry.subtract(const Duration(minutes: 5)),
          when: [Condition(Event.appForeground, value: "1")],
          callback: _refreshToken,
        ));
        return payload;
      }
    } catch (e) {
      onTokenExpired();
      throw Exception("Failed to get token info: $e");
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final token = _currentToken.now;
      if (token == null) return false;
      final payload = await _api.refresh(token);
      _currentToken.now = payload.token;
      onTokenRefreshed();
      return true;
    } catch (e) {
      onTokenExpired(); // TODO: may be too aggressive
      _currentToken.now = null;
      throw Exception("Failed to refresh token: $e");
    }
  }

  _startHeartbeat() async {
    final token = _currentToken.now;
    if (token == null) return;
    _scheduler.addOrUpdate(
        Job(
          _keyHeartbeat,
          every: _frequencyHeartbeat,
          when: [Condition(Event.appForeground, value: "1")],
          callback: () async => await _doHeartbeat(token),
        ),
        immediate: true);
  }

  Future<bool> _doHeartbeat(String token) async {
    try {
      print("sending heartbeat");
      await _api.sendHeartbeat(token);
      return true;
    } on HttpCodeException catch (e) {
      if (e.code == 401) {
        onTokenExpired();
        _currentToken.now = null;
        _scheduler.stop(_keyHeartbeat);
        print("token unavailable, stopping heartbeat");
        throw SchedulerException(e);
      } else {
        print("failed to send heartbeat: $e");
        throw SchedulerException(e, canRetry: true);
      }
    } catch (e) {
      print("failed to send heartbeat: $e");
      throw SchedulerException(e, canRetry: true);
    }
  }
}
