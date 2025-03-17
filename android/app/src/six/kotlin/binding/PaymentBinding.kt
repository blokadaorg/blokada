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
import channel.command.CommandName
import channel.payment.PaymentOps
import com.adapty.Adapty
import com.adapty.errors.AdaptyError
import com.adapty.models.AdaptyConfig
import com.adapty.models.AdaptyPaywallProduct
import com.adapty.models.AdaptyProfile
import com.adapty.models.AdaptyPurchaseResult
import com.adapty.ui.AdaptyPaywallView
import com.adapty.ui.AdaptyUI
import com.adapty.ui.listeners.AdaptyUiEventListener
import com.adapty.utils.AdaptyLogLevel
import com.adapty.utils.AdaptyResult
import com.adapty.utils.FileLocation
import com.adapty.utils.seconds
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService
import ui.AdaptyPaymentFragment
import ui.MainActivity

object PaymentBinding: PaymentOps, AdaptyUiEventListener {

    private val _scope = GlobalScope
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }
    private val commands by lazy { CommandBinding }

    private var _fragment: AdaptyPaymentFragment? = null
    private var _retry = true

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
            val location = FileLocation.fromAsset("fallbacks/six-android.json")
            Adapty.setFallbackPaywalls(location) { error ->
               if (error != null) throw error
            }
        } catch (e: Exception) {
            log("Adapty: Failed setting fallback, ignore", e)
        }
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
        Adapty.logShowOnboarding(name, stepName, stepOrder.toInt()) { error ->
            if (error == null) callback(Result.success(Unit))
            else callback(Result.failure(error))
        }
    }

    override fun doShowPaymentScreen(placementId: String, callback: (Result<Unit>) -> Unit) {
        _retry = true
        Adapty.getPaywall(placementId, locale = "en", loadTimeout = 10.seconds) { result ->
            when (result) {
                is AdaptyResult.Success -> {
                    val paywall = result.value
                    // the requested paywall
                    AdaptyUI.getViewConfiguration(paywall, loadTimeout = 10.seconds) { result ->
                        when(result) {
                            is AdaptyResult.Success -> {
                                val activity = context.requireActivity() as MainActivity
                                val viewConfiguration = result.value
                                // use loaded configuration
                                val view = AdaptyUI.getPaywallView(
                                    activity,
                                    viewConfiguration,
                                    null,
                                    this,
                                )
                                val fragment = AdaptyPaymentFragment.newInstance(view)
                                fragment.show(activity.supportFragmentManager, null)
                                _fragment = fragment
                                callback(Result.success(Unit))
                            }
                            is AdaptyResult.Error -> {
                                callback(Result.failure(result.error))
                            }
                        }
                    }
                }
                is AdaptyResult.Error -> {
                    callback(Result.failure(result.error))
                }
            }
        }
    }

    override fun doClosePaymentScreen(callback: (Result<Unit>) -> Unit) {
        closePaymentScreen()
        _retry = true
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
            else -> {

            }
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
                TODO("Not yet implemented")
            }
            is AdaptyUI.Action.Custom -> {

            }
        }
    }

    override fun onLoadingProductsFailure(error: AdaptyError, context: Context): Boolean {
        closePaymentScreen()
        log("Failed loading products", error)
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
        log("Failed purchase", error)
        handleFailure(restore = false, temporary = false)
    }

    override fun onRenderingError(error: AdaptyError, context: Context) {
        log("Failed rendering adapty", error)
    }

    override fun onRestoreFailure(error: AdaptyError, context: Context) {
        closePaymentScreen()
        log("Failed restore", error)
        handleFailure(restore = true, temporary = false)
    }

    override fun onAwaitingSubscriptionUpdateParams(
        product: AdaptyPaywallProduct,
        context: Context,
        onSubscriptionUpdateParamsReceived: AdaptyUiEventListener.SubscriptionUpdateParamsCallback
    ) {
    }

    private fun closePaymentScreen() {
        _fragment?.dismiss()
        _fragment = null
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

    private fun log(message: String, error: Throwable) {
        _scope.launch {
            val errorString = "$message: ${error.message}"
            commands.execute(CommandName.WARNING, errorString)
        }
    }

    // Unused interface methods below

    override fun onProductSelected(product: AdaptyPaywallProduct, context: Context) {
    }

    override fun onPurchaseStarted(product: AdaptyPaywallProduct, context: Context) {
    }

    override fun onRestoreStarted(context: Context) {
    }
}
