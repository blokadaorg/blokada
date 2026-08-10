part of '../adapty_refund_preference.dart';

extension AdaptyRefundPreferenceJSONBuilder on AdaptyRefundPreference {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyRefundPreference.noPreference:
        return 'no_preference';
      case AdaptyRefundPreference.grant:
        return 'grant';
      case AdaptyRefundPreference.decline:
        return 'decline';
    }
  }
}
