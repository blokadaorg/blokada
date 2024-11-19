part of 'api.dart';

class AccountId extends AsyncValue<String> {}

class BaseUrl extends Value<String> {
  final Act _act;

  BaseUrl(this._act)
      : super(load: () {
          return _act.isFamily
              ? "https://family.api.blocka.net/"
              : "https://api.blocka.net/";
        });
}

class ApiRetryDuration extends Value<Duration> {
  final Act _act;

  ApiRetryDuration(this._act)
      : super(load: () {
          return Duration(seconds: _act.isProd ? 3 : 0);
        });
}

class UserAgent extends AsyncValue<String> {}
