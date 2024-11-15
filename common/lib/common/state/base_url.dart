part of 'state.dart';

class BaseUrl extends Value<String> {
  final Act _act;

  BaseUrl(this._act);

  @override
  doLoad() => _act.isFamily()
      ? "https://family.api.blocka.net/"
      : "https://api.blocka.net/";
}

class ApiRetryDuration extends Value<Duration> {
  final Act _act;

  ApiRetryDuration(this._act);

  @override
  doLoad() => Duration(seconds: _act.isProd() ? 3 : 0);
}
