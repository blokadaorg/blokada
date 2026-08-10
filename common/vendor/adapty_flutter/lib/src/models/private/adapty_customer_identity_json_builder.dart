part of '../adapty_customer_identity.dart';

extension AdaptyCustomerIdentityJSONBuilder on AdaptyCustomerIdentity {
  dynamic get jsonValue => {
        if (appAccountToken != null) _Keys.appAccountToken: appAccountToken,
        if (obfuscatedAccountId != null) _Keys.obfuscatedAccountId: obfuscatedAccountId,
      };
}

class _Keys {
  static const appAccountToken = 'app_account_token';
  static const obfuscatedAccountId = 'obfuscated_account_id';
}
