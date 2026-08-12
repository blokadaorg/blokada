//
//  adapty_flow_fetch_policy.dart
//  Adapty
//
//  Created by Aleksei Valiano on 12.12.2023.
//

part 'private/adapty_flow_fetch_policy_json_builder.dart';

sealed class AdaptyFlowFetchPolicy {
  static AdaptyFlowFetchPolicy reloadRevalidatingCacheData = ReloadRevalidatingCacheData();
  static AdaptyFlowFetchPolicy returnCacheDataElseLoad = ReturnCacheDataElseLoad();
  static AdaptyFlowFetchPolicy returnCacheDataIfNotExpiredElseLoad(Duration maxAge) => ReturnCacheDataIfNotExpiredElseLoad(maxAge);
}

final class ReloadRevalidatingCacheData extends AdaptyFlowFetchPolicy {}

final class ReturnCacheDataElseLoad extends AdaptyFlowFetchPolicy {}

final class ReturnCacheDataIfNotExpiredElseLoad extends AdaptyFlowFetchPolicy {
  final Duration maxAge;

  ReturnCacheDataIfNotExpiredElseLoad(this.maxAge);
}
