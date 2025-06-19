part of 'api.dart';

class FreemiumAwareHttp extends Http {
  final FreemiumDataProvider _dataProvider = FreemiumDataProvider();
  late final _accountStore = Core.get<AccountStore>();

  bool get _isFreemium {
      return _accountStore.isFreemium;
  }

  @override
  Future<String> call(
    HttpRequest payload,
    Marker m, {
    QueryParams? params,
    Headers headers = const {},
    bool skipResolvingParams = false,
  }) async {
    // Check if this endpoint should return mock data in freemium mode
    if (_isFreemium && _dataProvider.shouldMockEndpoint(payload.endpoint)) {
      log(m).i('Returning sample data for endpoint: ${payload.endpoint} (freemium mode)');
      return _dataProvider.getDataFor(payload.endpoint, params);
    }

    // Otherwise, use the real HTTP implementation
    return await super.call(payload, m,
        params: params, headers: headers, skipResolvingParams: skipResolvingParams);
  }
}
