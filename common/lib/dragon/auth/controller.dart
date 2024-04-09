import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/auth/api.dart';
import 'package:common/dragon/device/current_token.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';

const _key = "auth";

class AuthController {
  late final _api = dep<AuthApi>();
  late final _accountId = dep<AccountId>();
  late final _currentToken = dep<CurrentToken>();
  late final _timer = dep<TimerService>();

  Function() onTokenRefreshed = () {};
  Function() onTokenExpired = () {};

  start() async {
    _timer.addHandler(_key, _refreshToken);

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
        _timer.set(_key, payload.expiry.subtract(const Duration(minutes: 5)));
        return payload;
      }
    } catch (e) {
      onTokenExpired();
      throw Exception("Failed to get token info: $e");
    }
  }

  _refreshToken(Trace trace) async {
    try {
      final token = _currentToken.now;
      if (token == null) return;
      final payload = await _api.refresh(token);
      _currentToken.now = payload.token;
      onTokenRefreshed();
    } catch (e) {
      onTokenExpired(); // TODO: may be too aggressive
      _currentToken.now = null;
      trace.addEvent("Failed to refresh token: $e");
      throw Exception("Failed to refresh token: $e");
    }
  }

  _startHeartbeat() async {
    final token = _currentToken.now;
    if (token == null) return;
    _doHeartbeat(token);
  }

  _doHeartbeat(String token) async {
    try {
      print("sending heartbeat");
      await _api.sendHeartbeat(token);
      Future.delayed(_frequency, () => _doHeartbeat(token));
    } on HttpCodeException catch (e) {
      if (e.code == 401) {
        onTokenExpired();
        _currentToken.now = null;
        print("token unavailable, stopping heartbeat");
      } else {
        print("failed to send heartbeat: $e");
      }
    } catch (e) {
      print("failed to send heartbeat: $e");
      // xxxx: deal
    }
  }
}

const _frequency = Duration(minutes: 30);
