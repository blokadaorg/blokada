//
//  adapty_flow_fetch_policy_json_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 12.12.2023.
//

part of '../adapty_flow_fetch_policy.dart';

extension AdaptyFlowFetchPolicyJSONBuilder on AdaptyFlowFetchPolicy {
  dynamic get jsonValue {
    switch (this) {
      case ReloadRevalidatingCacheData():
        return {_Keys.type: _Values.reloadRevalidatingCacheData};
      case ReturnCacheDataElseLoad():
        return {_Keys.type: _Values.returnCacheDataElseLoad};
      case ReturnCacheDataIfNotExpiredElseLoad(maxAge: Duration maxAge):
        return {
          _Keys.type: _Values.returnCacheDataIfNotExpiredElseLoad,
          _Keys.maxAge: maxAge.inMilliseconds.toDouble() / 1000.0,
        };
    }
  }
}

class _Keys {
  static const type = 'type';
  static const maxAge = 'max_age';
}

class _Values {
  static const reloadRevalidatingCacheData = 'reload_revalidating_cache_data';
  static const returnCacheDataElseLoad = 'return_cache_data_else_load';
  static const returnCacheDataIfNotExpiredElseLoad = 'return_cache_data_if_not_expired_else_load';
}
