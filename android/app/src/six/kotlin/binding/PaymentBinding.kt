/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import android.content.Context
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import channel.command.CommandName
import channel.payment.PaymentOps
import com.adapty.Adapty
import com.adapty.errors.AdaptyError
import com.adapty.models.AdaptyConfig
import com.adapty.models.AdaptyPaywallProduct
import com.adapty.models.AdaptyProfile
import com.adapty.models.AdaptyPurchaseResult
import com.adapty.models.AdaptySubscriptionUpdateParameters
import com.adapty.ui.AdaptyPaywallView
import com.adapty.ui.AdaptyUI
import com.adapty.ui.listeners.AdaptyUiEventListener
import com.adapty.utils.AdaptyLogLevel
import com.adapty.utils.AdaptyResult
import com.adapty.utils.FileLocation
import com.adapty.utils.seconds
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService
import ui.AdaptyPaymentFragment
import ui.MainActivity
import utils.Intents
import kotlin.coroutines.suspendCoroutine

object PaymentBinding : PaymentOps, AdaptyUiEventListener {

    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }
    private val commands by lazy { CommandBinding }
    private val intents by lazy { Intents }

    private var _fragment: AdaptyPaymentFragment? = null
    private var _retry = true

    private var _currentSubscriptionProductId: String? = null
    private var _currentView: AdaptyPaywallView? = null
    private var _currentViewForPlacementId: String? = null

    private val _scope = CoroutineScope(Dispatchers.Main)

    init {
        PaymentOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doInit(
        apiKey: String,
        accountId: String?,
        verboseLogs: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        Adapty.logLevel = if (verboseLogs) AdaptyLogLevel.VERBOSE else AdaptyLogLevel.WARN
        Adapty.activate(
            context.requireAppContext(),
            AdaptyConfig.Builder(apiKey)
                .withObserverMode(false)
                .withCustomerUserId(accountId)
                .withIpAddressCollectionDisabled(true)
                .withAdIdCollectionDisabled(true)
                .build()
        )

        try {
            val location = FileLocation.fromAsset("fallbacks/android.json")
            Adapty.setFallbackPaywalls(location) { error ->
                if (error != null) {
                    logError("Adapty: Error when setting fallback, ignore", error)
                }
            }
        } catch (e: Throwable) {
            // Catch probably not needed, exception is passed through callback
            // and since it's using suspended coroutines internally, it seemed
            // to not be catchable like this
            logError("Adapty: Failed setting fallback, ignore", e)
        }
        callback(Result.success(Unit))
    }

    override fun doIdentify(accountId: String, callback: (Result<Unit>) -> Unit) {
        Adapty.identify(accountId) { error ->
            if (error == null) callback(Result.success(Unit))
            else callback(Result.failure(error))
        }
    }

    override fun doLogOnboardingStep(
        name: String,
        stepName: String,
        stepOrder: Long,
        callback: (Result<Unit>) -> Unit
    ) {
//        Adapty.logShowOnboarding(name, stepName, stepOrder.toInt()) { error ->
//            if (error == null) callback(Result.success(Unit))
//            else callback(Result.failure(error))
//        }
        callback(Result.success(Unit))
    }

    override fun doPreload(placementId: String, callback: (Result<Unit>) -> Unit) {
        getActivityScope()?.launch {
            try {
                _currentSubscriptionProductId = fetchCurrentSubscriptionProductId()
                _currentView = fetchPaywall(placementId)
                _currentViewForPlacementId = placementId
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        } ?: callback(Result.failure(Exception("No activity context")))
    }

    override fun doShowPaymentScreen(
        placementId: String,
        forceReload: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        _retry = true
        getActivityScope()?.launch {
            try {
                if (forceReload || _currentViewForPlacementId != placementId) {
                    _currentSubscriptionProductId = fetchCurrentSubscriptionProductId()
                    _currentView = fetchPaywall(placementId)
                    _currentViewForPlacementId = placementId
                }

                val activity = context.requireActivity() as MainActivity
                _fragment = AdaptyPaymentFragment.newInstance(_currentView!!)
                _fragment!!.show(activity.supportFragmentManager, null)

                // Drop preload after one use since we cannot reuse the view
                _currentViewForPlacementId = null
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        } ?: callback(Result.failure(Exception("No activity context")))
    }

    private suspend fun fetchPaywall(placementId: String): AdaptyPaywallView {
        return suspendCoroutine { continuation ->
            Adapty.getPaywall(placementId, locale = "en", loadTimeout = 10.seconds) { result ->
                when (result) {
                    is AdaptyResult.Success -> {
                        val paywall = result.value
                        // the requested paywall
                        AdaptyUI.getViewConfiguration(paywall, loadTimeout = 10.seconds) { result ->
                            when (result) {
                                is AdaptyResult.Success -> {
                                    if (!context.hasActivityContext()) {
                                        continuation.resumeWith(
                                            Result.failure(
                                                Exception("Activity context no longer available")
                                            )
                                        )
                                        return@getViewConfiguration
                                    }

                                    try {
                                        val activity = context.requireActivity() as MainActivity
                                        val viewConfiguration = result.value
                                        // use loaded configuration
                                        val view = AdaptyUI.getPaywallView(
                                            activity,
                                            viewConfiguration,
                                            null,
                                            this,
                                        )
                                        continuation.resumeWith(Result.success(view))
                                    } catch (e: Exception) {
                                        continuation.resumeWith(Result.failure(e))
                                    }
                                }

                                is AdaptyResult.Error -> {
                                    continuation.resumeWith(Result.failure(result.error))
                                }
                            }
                        }
                    }

                    is AdaptyResult.Error -> {
                        continuation.resumeWith(Result.failure(result.error))
                    }
                }
            }
        }
    }

    private suspend fun fetchCurrentSubscriptionProductId(): String? {
        return suspendCoroutine { continuation ->
            Adapty.getProfile { result ->
                when (result) {
                    is AdaptyResult.Success -> {
                        log("Adapty profileId: ${result.value.profileId}")
                        val subId =
                            result.value.accessLevels.values.firstOrNull { it.isActive }?.vendorProductId?.substringBefore(
                                ":"
                            )
                        continuation.resumeWith(Result.success(subId))
                    }

                    is AdaptyResult.Error -> {
                        continuation.resumeWith(Result.failure(result.error))
                    }
                }
            }
        }

    }

    override fun doClosePaymentScreen(callback: (Result<Unit>) -> Unit) {
        closePaymentScreen()
        _retry = true
        callback(Result.success(Unit))
    }

    // AdaptyUiEventListener implemented from here downward

    override fun onPurchaseFinished(
        purchaseResult: AdaptyPurchaseResult,
        product: AdaptyPaywallProduct,
        context: Context
    ) {
        when (purchaseResult) {
            is AdaptyPurchaseResult.Success -> {
                closePaymentScreen()
                handleSuccess(purchaseResult.profile.profileId, restore = false)
            }

            else -> {}
        }
    }

    override fun onRestoreSuccess(profile: AdaptyProfile, context: Context) {
        closePaymentScreen()
        handleSuccess(profile.profileId, restore = true)
    }

    override fun onActionPerformed(action: AdaptyUI.Action, context: Context) {
        when (action) {
            AdaptyUI.Action.Close -> {
                closePaymentScreen()
            }

            is AdaptyUI.Action.OpenUrl -> {
                val intent = intents.createOpenInBrowserIntent(action.url)
                intents.openIntentActivity(context, intent)
            }

            is AdaptyUI.Action.Custom -> {

            }
        }
    }

    override fun onLoadingProductsFailure(error: AdaptyError, context: Context): Boolean {
        closePaymentScreen()
        logError("Failed loading products", error)
        handleFailure(restore = false, temporary = true)

        // Just one retry
        val retry = _retry
        if (retry) _retry = false
        return retry
    }

    override fun onPurchaseFailure(
        error: AdaptyError,
        product: AdaptyPaywallProduct,
        context: Context
    ) {
        closePaymentScreen()
        logError("Failed purchase", error)
        handleFailure(restore = false, temporary = false)
    }

    override fun onRenderingError(error: AdaptyError, context: Context) {
        logError("Failed rendering adapty", error)
    }

    override fun onRestoreFailure(error: AdaptyError, context: Context) {
        closePaymentScreen()
        logError("Failed restore", error)
        handleFailure(restore = true, temporary = false)
    }

    override fun onAwaitingSubscriptionUpdateParams(
        product: AdaptyPaywallProduct,
        context: Context,
        onSubscriptionUpdateParamsReceived: AdaptyUiEventListener.SubscriptionUpdateParamsCallback
    ) {
        // TODO: no support for downgrading yet
        val subId = _currentSubscriptionProductId
        if (subId != null) {
            onSubscriptionUpdateParamsReceived(
                AdaptySubscriptionUpdateParameters(
                    subId,
                    AdaptySubscriptionUpdateParameters.ReplacementMode.CHARGE_PRORATED_PRICE
                )
            )
        } else {
            onSubscriptionUpdateParamsReceived(null)
        }
    }

    private fun closePaymentScreen() {
        _fragment?.dismiss()
        _fragment = null
        handleScreenClosed()
    }

    private fun handleSuccess(profileId: String, restore: Boolean) {
        _scope.launch {
            val restoreString = if (restore) "1" else "0"
            commands.execute(CommandName.PAYMENTHANDLESUCCESS, profileId, restoreString)
        }
    }

    private fun handleFailure(restore: Boolean, temporary: Boolean) {
        _scope.launch {
            val restoreString = if (restore) "1" else "0"
            val temporaryString = if (temporary) "1" else "0"
            commands.execute(CommandName.PAYMENTHANDLEFAILURE, restoreString, temporaryString)
        }
    }

    fun handleScreenClosed() {
        _scope.launch {
            commands.execute(CommandName.PAYMENTHANDLESCREENCLOSED)
        }
    }

    private fun logError(message: String, error: Throwable) {
        _scope.launch {
            val errorString = "$message: ${error.message}"
            commands.execute(CommandName.WARNING, errorString)
        }
    }

    private fun log(message: String) {
        _scope.launch {
            commands.execute(CommandName.INFO, message)
        }
    }

    // Returns scope to execute coroutines in. We need activity scope for the paywall itself,
    // but other operations are more lenient. We want to make sure the success checkout is as
    // certain as possible, so we don't use the activity scope for that.
    private fun getActivityScope(): CoroutineScope? {
        if (!context.hasActivityContext()) return null
        return (context.requireActivity() as LifecycleOwner).lifecycleScope
    }

    // Unused interface methods below

    override fun onProductSelected(product: AdaptyPaywallProduct, context: Context) {
        Log.d("adapty", "product selected")
    }

    override fun onPurchaseStarted(product: AdaptyPaywallProduct, context: Context) {
        Log.d("adapty", "purchase started")
    }

    override fun onRestoreStarted(context: Context) {
        Log.d("adapty", "restore started")
    }
}
