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
import com.adapty.models.AdaptyProfileParameters
import com.adapty.models.AdaptyPurchaseParameters
import com.adapty.models.AdaptyPurchaseResult
import com.adapty.models.AdaptySubscriptionUpdateParameters
import com.adapty.ui.AdaptyPaywallView
import com.adapty.ui.AdaptyUI
import com.adapty.ui.listeners.AdaptyUiEventListener
import com.adapty.utils.AdaptyLogLevel
import com.adapty.utils.AdaptyResult
import com.adapty.utils.FileLocation
import com.adapty.utils.seconds
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService
import service.TranslationService
import ui.AdaptyPaymentFragment
import ui.MainActivity
import utils.Intents

object PaymentBinding : PaymentOps, AdaptyUiEventListener {

    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }
    private val commands by lazy { CommandBinding }
    private val translate by lazy { TranslationService }
    private val intents by lazy { Intents }

    private var _fragment: AdaptyPaymentFragment? = null
    private var _retry = true

    private var _currentSubscription: CurrentSubscription? = null
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
            Adapty.setFallback(location) { error ->
                if (error != null) {
                    logError("Error when setting fallback, ignore", error)
                }
            }
        } catch (e: Throwable) {
            // Catch probably not needed, exception is passed through callback
            // and since it's using suspended coroutines internally, it seemed
            // to not be catchable like this
            logError("Failed setting fallback, ignore", e)
        }

        Adapty.setOnProfileUpdatedListener { profile ->
            _scope.launch {
                try {
                    maybeRestoreSubscription()
                } catch (e: Throwable) {
                    // Profile update callbacks are best-effort; do not crash app on backend errors.
                    logError("Failed profile-updated restore, ignore", e)
                }
            }
        }

        callback(Result.success(Unit))
    }

    override fun doIdentify(accountId: String, callback: (Result<Unit>) -> Unit) {
        Adapty.identify(accountId) { error ->
            if (error == null) callback(Result.success(Unit)) else callback(Result.failure(error))
        }
    }

    override fun doSetCustomAttributes(
        attributes: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            val builder = AdaptyProfileParameters.Builder()

            // Extract pre-processed custom attributes from Flutter
            val customAttributes = attributes["custom_attributes"] as? List<Map<String, Any?>>

            if (customAttributes != null) {
                // Add each pre-processed attribute to the builder
                for (attr in customAttributes) {
                    val key = attr["key"] as? String
                    val value = attr["value"]
                    if (key != null && value != null) {
                        when (value) {
                            is String -> builder.withCustomAttribute(key, value)
                            is Double -> builder.withCustomAttribute(key, value)
                            is Number -> builder.withCustomAttribute(key, value.toDouble())
                            else -> builder.withCustomAttribute(key, value.toString())
                        }
                    }
                }
            }

            Adapty.updateProfile(builder.build()) { error ->
                if (error == null) callback(Result.success(Unit))
                else callback(Result.failure(error))
            }
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun doLogOnboardingStep(
        name: String,
        stepName: String,
        stepOrder: Long,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            Adapty.logShowOnboarding(name, stepName, stepOrder.toInt()) { error ->
                if (error == null) callback(Result.success(Unit))
                else callback(Result.failure(error))
            }
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun doPreload(placementId: String, callback: (Result<Unit>) -> Unit) {
        getActivityScope()?.launch {
            try {
                maybeRestoreSubscription()
                _currentView = fetchPaywall(placementId)
                _currentViewForPlacementId = placementId

                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
            ?: callback(Result.failure(Exception("No activity context")))
    }

    // Automatically recover subscription if user has one
    // (android only, to prevent double sub)
    private suspend fun maybeRestoreSubscription() {
        val currentSubscription = fetchCurrentSubscription()
        if (currentSubscription != null) {
            log("Found existing active subscription, restoring")
            handleSuccess(currentSubscription.profileId, restore = true)
        }
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
                    _currentSubscription = fetchCurrentSubscription()
                    _currentView = fetchPaywall(placementId)
                    _currentViewForPlacementId = placementId
                }

                val activity = context.requireActivity() as MainActivity
                val manager = activity.supportFragmentManager
                val tag = "adapty"
                val existingFragment = manager.findFragmentByTag(tag)
                if (existingFragment != null) {
                    manager.beginTransaction().remove(existingFragment).commitNow()
                    log("Removed existing adapty fragment")
                }

                val fragment = AdaptyPaymentFragment.newInstance(_currentView!!)
                _fragment = fragment

                // Ensure the transaction completes with commitNow instead of relying on show()
                val transaction = manager.beginTransaction()
                transaction.add(fragment, tag)
                transaction.commitNow()

                // Drop preload after one use since we cannot reuse the view
                _currentViewForPlacementId = null
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
            ?: callback(Result.failure(Exception("No activity context")))
    }

    private suspend fun fetchPaywall(placementId: String): AdaptyPaywallView {
        return suspendCoroutine { continuation ->
            Adapty.getPaywall(
                placementId,
                locale = translate.getLocale(),
                loadTimeout = 10.seconds
            ) { result ->
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
                                                Exception(
                                                    "Activity context no longer available"
                                                )
                                            )
                                        )
                                        return@getViewConfiguration
                                    }

                                    try {
                                        val activity = context.requireActivity() as MainActivity
                                        val viewConfiguration = result.value
                                        // use loaded configuration
                                        val view =
                                            AdaptyUI.getPaywallView(
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

    // Fetch current subscription product_id, needed for handling prorate things.
    // Also check for existing access level to trigger restore and prevent user
    // from simultaneously subscribing to two plans.
    private suspend fun fetchCurrentSubscription(): CurrentSubscription? {
        return suspendCoroutine { continuation ->
            Adapty.getProfile { result ->
                when (result) {
                    is AdaptyResult.Success -> {
                        log("ProfileId: ${result.value.profileId}")
                        val firstActiveSub =
                            result.value.accessLevels.values.firstOrNull { it.isActive }

                        if (firstActiveSub == null) {
                            continuation.resumeWith(Result.success(null))
                            return@getProfile
                        }

                        val sub =
                            CurrentSubscription(
                                profileId = result.value.profileId,
                                productId =
                                    firstActiveSub.vendorProductId.substringBefore(":")
                            )

                        continuation.resumeWith(Result.success(sub))
                    }

                    is AdaptyResult.Error -> {
                        continuation.resumeWith(Result.failure(result.error))
                    }
                }
            }
        }
    }

    override fun doClosePaymentScreen(isError: Boolean, callback: (Result<Unit>) -> Unit) {
        closePaymentScreen(isError)
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
                closePaymentScreen(false)
                handleSuccess(purchaseResult.profile.profileId, restore = false)
            }

            else -> {}
        }
    }

    override fun onRestoreSuccess(profile: AdaptyProfile, context: Context) {
        closePaymentScreen(false)
        handleSuccess(profile.profileId, restore = true)
    }

    override fun onActionPerformed(action: AdaptyUI.Action, context: Context) {
        when (action) {
            AdaptyUI.Action.Close -> {
                closePaymentScreen(false)
            }

            is AdaptyUI.Action.OpenUrl -> {
                val intent = intents.createOpenInBrowserIntent(action.url)
                intents.openIntentActivity(context, intent)
            }

            is AdaptyUI.Action.Custom -> {}
        }
    }

    override fun onLoadingProductsFailure(error: AdaptyError, context: Context): Boolean {
        closePaymentScreen(true)
        logError("Failed loading products", error)
        handleFailure(restore = false, temporary = true)

        // Just one retry
        val retry = _retry
        if (retry) _retry = false
        return retry
    }

    override fun onPaywallClosed() {
    }

    override fun onPaywallShown(context: Context) {
    }

    override fun onPurchaseFailure(
        error: AdaptyError,
        product: AdaptyPaywallProduct,
        context: Context
    ) {
        closePaymentScreen(true)
        logError("Failed purchase", error)
        handleFailure(restore = false, temporary = false)
    }

    override fun onRenderingError(error: AdaptyError, context: Context) {
        logError("Failed rendering adapty", error)
    }

    override fun onRestoreFailure(error: AdaptyError, context: Context) {
        closePaymentScreen(true)
        logError("Failed restore", error)
        handleFailure(restore = true, temporary = false)
    }


    override fun onAwaitingPurchaseParams(
        product: AdaptyPaywallProduct,
        context: Context,
        onPurchaseParamsReceived: AdaptyUiEventListener.PurchaseParamsCallback
    ): AdaptyUiEventListener.PurchaseParamsCallback.IveBeenInvoked {
        // TODO: no support for downgrading yet
        val sub = _currentSubscription
        if (sub != null) {
            onPurchaseParamsReceived(
                AdaptyPurchaseParameters.Builder().withSubscriptionUpdateParams(
                    AdaptySubscriptionUpdateParameters(
                        sub.productId,
                        AdaptySubscriptionUpdateParameters.ReplacementMode.CHARGE_PRORATED_PRICE
                    )
                ).build()
            )
        } else {
            onPurchaseParamsReceived(AdaptyPurchaseParameters.Empty)
        }
        return AdaptyUiEventListener.PurchaseParamsCallback.IveBeenInvoked
    }

    private fun closePaymentScreen(isError: Boolean) {
        _fragment?.dismiss()
        _fragment = null
        handleScreenClosed(isError)
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

    fun handleScreenClosed(isError: Boolean) {
        val err = if (isError) "1" else "0"
        _scope.launch { commands.execute(CommandName.PAYMENTHANDLESCREENCLOSED, err) }
    }

    fun logError(message: String, error: Throwable) {
        _scope.launch {
            val errorString = "Adapty: $message: ${error.message}"
            commands.execute(CommandName.WARNING, errorString)
        }
    }

    private fun log(message: String) {
        _scope.launch { commands.execute(CommandName.INFO, "Adapty: $message") }
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
        Log.d("Adapty", "product selected")
    }

    override fun onPurchaseStarted(product: AdaptyPaywallProduct, context: Context) {
        Log.d("Adapty", "purchase started")
    }

    override fun onRestoreStarted(context: Context) {
        Log.d("Adapty", "restore started")
    }
}

private data class CurrentSubscription(val profileId: String, val productId: String)
