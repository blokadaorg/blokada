//
//  adapty_error_code.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

class AdaptyErrorCode {
  //////////////////////////////
  /// System StoreKit codes. ///
  //////////////////////////////

  /// Error code indicating that an unknown or unexpected error occurred.
  static const int unknown = 0;

  /// Error code indicating that the client is not allowed to perform the attempted action.
  static const int clientInvalid = 1;

  /// Error code indicating that the user canceled a payment request.
  static const int paymentCancelled = 2;

  /// Error code indicating that one of the payment parameters was not recognized by the App Store.
  static const int paymentInvalid = 3;

  /// Error code indicating that the user is not allowed to authorize payments.
  static const int paymentNotAllowed = 4;

  /// Error code indicating that the requested product is not available in the store.
  static const int storeProductNotAvailable = 5;

  /// Error code indicating that the user has not allowed access to Cloud service information.
  static const int cloudServicePermissionDenied = 6;

  /// Error code indicating that the device could not connect to the network.
  static const int cloudServiceNetworkConnectionFailed = 7;

  /// Error code indicating that the user has revoked permission to use this cloud service.
  static const int cloudServiceRevoked = 8;

  /// Error code indicating that the user has not yet acknowledged Apple’s privacy policy.
  static const int privacyAcknowledgementRequired = 9;

  /// Error code indicating that the app is attempting to use a property for which it does not have the required entitlement.
  static const int unauthorizedRequestData = 10;

  /// Error code indicating that the offer identifier is invalid.
  static const int invalidOfferIdentifier = 11;

  /// Error code indicating that the signature in a payment discount is not valid.
  static const int invalidSignature = 12;

  /// Error code indicating that parameters are missing in a payment discount.
  static const int missingOfferParams = 13;

  /// Error code indicating that the price you specified in App Store Connect is no longer valid.
  static const int invalidOfferPrice = 14;

  /////////////////////////////
  /// Custom Android codes. ///
  /////////////////////////////

  static const int adaptyNotInitialized = 20;
  static const int productNotFound = 22;
  static const int invalidJson = 23;
  static const int currentSubscriptionToUpdateNotFoundInHistory = 24;
  static const int pendingPurchase = 25;
  static const int billingServiceTimeout = 97;
  static const int featureNotSupported = 98;
  static const int billingServiceDisconnected = 99;
  static const int billingServiceUnavailable = 102;
  static const int billingUnavailable = 103;
  static const int developerError = 105;
  static const int billingError = 106;
  static const int itemAlreadyOwned = 107;
  static const int itemNotOwned = 108;

  //////////////////////////////
  /// Custom StoreKit codes. ///
  //////////////////////////////

  /// No In-App Purchase product identifiers were found.
  static const int noProductIDsFound = 1000;

  /// Unable to fetch available In-App Purchase products at the moment.
  static const int productRequestFailed = 1002;

  /// In-App Purchases are not allowed on this device.
  static const int cantMakePayments = 1003;

  /// No purchases to restore.
  static const int noPurchasesToRestore = 1004;

  /// Can't find a valid receipt.
  static const int cantReadReceipt = 1005;

  /// Product purchase failed.
  static const int productPurchaseFailed = 1006;

  /// Receipt refresh operation has been failed.
  static const int refreshReceiptFailed = 1010;

  /// Error occurred in the process of restoring purchases.
  static const int receiveRestoredTransactionsFailed = 1011;

  /////////////////////////////
  /// Custom network codes. ///
  /////////////////////////////

  /// You need to be authenticated to perform requests.
  static const int notActivated = 2002;

  /// Bad request
  static const int badRequest = 2003;

  /// Response code is 429 or 500s.
  static const int serverError = 2004;

  /// Network request failed
  static const int networkFailed = 2005;

  /// We could not decode the response.
  static const int decodingFailed = 2006;

  /// Parameters encoding failed.
  static const int encodingFailed = 2009;
  static const int analyticsDisabled = 3000;

  /// Wrong parameter was passed.
  static const int wrongParam = 3001;

  /// It is not possible to call `.activate` method more than once.
  static const int activateOnceError = 3005;

  /// The user profile was changed during the operation.
  static const int profileWasChanged = 3006;

  static const int unsupportedData = 3007;

  static const int fetchTimeoutError = 3101;

  /////////////////////////
  /// Custom UI codes. ///
  /////////////////////////

  /// An exception was thrown from JS during AdaptyUI flow execution.
  static const int jsException = 4105;

  /// This operation was interrupted by the system.
  static const int operationInterrupted = 9000;

  //////////////////////////////
  /////// Plugin codes. ///////
  //////////////////////////////

  static const int emptyResult = 10001;
  static const int internalPluginError = 10002;
}
