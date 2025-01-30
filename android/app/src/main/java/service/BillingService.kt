/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import channel.payment.Product
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingFlowParams.SubscriptionUpdateParams.ReplacementMode.CHARGE_PRORATED_PRICE
import com.android.billingclient.api.BillingFlowParams.SubscriptionUpdateParams.ReplacementMode.DEFERRED
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.queryProductDetails
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import model.BlokadaException
import model.NoPayments
import model.NoRelevantPurchase
import model.PaymentPayload
import model.ProductId
import model.runIgnoringException
import utils.Logger
import kotlin.coroutines.resumeWithException

val userCancelled = Exception("Payment sheet dismissed")
val alreadyPurchased = Exception("Already purchased")

object BillingService: IPaymentService {

    private val context by lazy { ContextService }

    private lateinit var client: BillingClient
    private var connected = false
        @Synchronized set
        @Synchronized get

    private var latestProductList: List<ProductDetails> = emptyList()
        @Synchronized set
        @Synchronized get

    private var ongoingPurchase: Pair<ProductId, CancellableContinuation<PaymentPayload>>? = null
        @Synchronized set
        @Synchronized get

    override suspend fun setup() {
        client = BillingClient.newBuilder(context.requireAppContext())
            .setListener(purchaseListener)
            // Skipping this call causes the client to fail setup
            .enablePendingPurchases()
            //.enablePendingPurchases(PendingPurchasesParams.newBuilder().enablePrepaidPlans().build())
            .build()
    }

    private suspend fun getConnectedClient(): BillingClient {
        if (connected) return client
        return suspendCancellableCoroutine<BillingClient> { cont ->
            client.startConnection(object : BillingClientStateListener {

                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    when (billingResult.responseCode) {
                        BillingClient.BillingResponseCode.OK -> {
                            connected = true
                            cont.resume(client) {
                                Logger.w("Billing", "Cancelled getConnectedClient()")
                            }
                        }
                        BillingClient.BillingResponseCode.BILLING_UNAVAILABLE -> {
                            connected = false
                            cont.resumeWithException(NoPayments())
                        }
                        else -> {
                            connected = false
                            cont.resumeWithException(
                                BlokadaException(
                                    "onBillingSetupFinished returned wrong result: $billingResult"
                                )
                            )
                        }
                    }
                }

                // Not sure if this is ever called as a result of startConnection or only later
                override fun onBillingServiceDisconnected() {
                    connected = false
                    if (!cont.isCompleted)
                        cont.resumeWithException(BlokadaException("onBillingServiceDisconnected"))
                }

            })
        }
    }

    override suspend fun refreshProducts(): List<Product> {
        val idsV6 = listOf("cloud_12month", "plus_month", "plus_12month")
        val idsFamily = listOf("family_month", "family_12months")

        val ids = if (Flavor.isFamily()) idsFamily else idsV6

        val params = QueryProductDetailsParams.newBuilder()
        params.setProductList(ids.map {
            QueryProductDetailsParams.Product.newBuilder()
            .setProductId(it)
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        })

        // leverage queryProductDetails Kotlin extension function
        val productDetailsResult = withContext(Dispatchers.IO) {
            getConnectedClient().queryProductDetails(params.build())
        }

        latestProductList = productDetailsResult.productDetailsList ?: emptyList()
        val payments = productDetailsResult.productDetailsList?.mapNotNull {
            val offer = it.subscriptionOfferDetails?.first()
            val phase = offer?.pricingPhases?.pricingPhaseList?.firstOrNull { it.priceAmountMicros > 0 }

            if (offer == null || phase == null) {
                null
            } else {
                var type = if(it.productId.startsWith("cloud")) "cloud" else "plus"
                if (it.productId.startsWith("family")) type = "family"

                Product(
                    id = it.productId,
                    title = it.title,
                    description = it.description,
                    price = getPriceString(phase),
                    pricePerMonth = getPricePerMonthString(phase),
                    periodMonths = getPeriodMonths(phase).toLong(),
                    type = type,
                    trial = getTrial(offer),
                    owned = false
                )
            }
        }?.sortedBy { it.periodMonths } ?: emptyList()
        if (payments.isEmpty()) throw NoPayments()
        return payments
    }

    private val purchaseListener = PurchasesUpdatedListener { billingResult, purchases ->
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            ongoingPurchase?.let { c ->
                val (productId, cont) = c
                val purchase = purchases
                    .sortedByDescending { it.purchaseTime }
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .firstOrNull { it.products.any { it == productId } }

                if (purchase == null) {
                    Logger.w("Billing", "No relevant purchase found. Expected product: $productId, Purchases: ${purchases.map { it.products }}")

                    cont.resumeWithException(NoRelevantPurchase())
                } else {
                    //Logger.v("Billing", "Purchase id: ${productId} token: ${purchase.purchaseToken}")
                    cont.resume(PaymentPayload(
                        purchase_token = purchase.purchaseToken,
                        subscription_id = productId,
                        user_initiated = true
                    ), {})
                }
            } ?: run {
                Logger.w("Billing", "There was no ongoing purchase")
            }
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // Handle an error caused by a user cancelling the purchase flow.
            Logger.v("Billing", "buyProduct: User cancelled purchase")
            ongoingPurchase?.second?.resumeWithException(userCancelled)
        } else {
            // Handle any other error codes.
            Logger.w("Billing", "buyProduct: Purchase error: $billingResult")
            val exception = if (billingResult.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                alreadyPurchased
            } else BlokadaException("Purchase error: $billingResult")

            ongoingPurchase?.second?.resumeWithException(exception)
        }
        ongoingPurchase = null
    }

    override suspend fun getActivePurchase(): ProductId? {
        var result: CancellableContinuation<ProductId?>? = null
        getConnectedClient().queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType("subs").build()
        ) { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                val successfulPurchases = purchases
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .sortedByDescending { it.purchaseTime }

                result?.resume(successfulPurchases.firstOrNull()?.products?.firstOrNull(), {})
            } else {
                result?.resumeWithException(
                    BlokadaException("Failed refreshing purchases, response code not OK")
                )
            }
        }

        return suspendCancellableCoroutine { cont ->
            result = cont
        }
    }

    override suspend fun buyProduct(id: ProductId): PaymentPayload {
        if (runIgnoringException({ restorePurchase() }, otherwise = emptyList()).isNotEmpty())
            throw alreadyPurchased

        val details = latestProductList.firstOrNull { it.productId == id } ?:
            throw BlokadaException("Unknown product ID")
        val offerToken = details.subscriptionOfferDetails!!.first().offerToken

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .setOfferToken(offerToken)
                .build()
            ))
            .build()
        val activity = context.requireActivity()
        val responseCode = getConnectedClient().launchBillingFlow(activity, flowParams).responseCode

        if (responseCode != BillingClient.BillingResponseCode.OK) {
            throw BlokadaException("buyProduct: error $responseCode")
        }

        return suspendCancellableCoroutine { cont ->
            ongoingPurchase = id to cont
        }
    }

    private var ongoingRestore: CancellableContinuation<List<PaymentPayload>>? = null
        @Synchronized set
        @Synchronized get

    override suspend fun restorePurchase(): List<PaymentPayload> {
        getConnectedClient().queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType("subs").build()
        ) { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                val successfulPurchases = purchases
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .sortedByDescending { it.purchaseTime }

                if (successfulPurchases.isNotEmpty()) {
                    Logger.w("Billing", "restore: Restoring ${successfulPurchases.size} purchases")
                    ongoingRestore?.resume(successfulPurchases.map {
                        PaymentPayload(
                            purchase_token = it.purchaseToken,
                            subscription_id = it.products.first(),
                            user_initiated = false
                        )
                    }, {})
                } else {
                    ongoingRestore?.resumeWithException(
                        BlokadaException("Restoring purchase found no successful purchases")
                    )
                }
            } else {
                ongoingRestore?.resumeWithException(
                    BlokadaException("Restoring purchase error: $billingResult")
                )
            }
            ongoingRestore = null
        }

        return suspendCancellableCoroutine { cont ->
            ongoingRestore = cont
        }
    }

    override suspend fun changeProduct(id: ProductId): PaymentPayload {
        val details = latestProductList.firstOrNull { it.productId == id } ?:
            throw BlokadaException("Unknown product ID")
        val offerToken = details.subscriptionOfferDetails!!.first().offerToken

        // Get existing subscription token
        getConnectedClient().queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType("subs").build()
        ) { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                // Get latest successful assuming it's the current one
                val existingPurchase = purchases
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .sortedByDescending { it.purchaseTime }
                    .firstOrNull()

                if (existingPurchase != null) {
                    Logger.w("Billing", "changeProduct: found subscription to use: $existingPurchase")

                    ongoingRestore?.resume(listOf(
                        PaymentPayload(
                            purchase_token = existingPurchase.purchaseToken,
                            subscription_id = existingPurchase.products.first(),
                            user_initiated = false
                        )
                    ), {})
                } else {
                    ongoingRestore?.resumeWithException(
                        BlokadaException("changeProduct: no existing purchase")
                    )
                }
            } else {
                ongoingRestore?.resumeWithException(
                    BlokadaException("changeProduct: error: $billingResult")
                )
            }
            ongoingRestore = null
        }

        // Wait until above async callback completes
        val existingPurchase = suspendCancellableCoroutine<List<PaymentPayload>> { cont ->
            ongoingRestore = cont
        }

        val existingId = existingPurchase.first().subscription_id
        val existingToken = existingPurchase.first().purchase_token

        val prorate = when {
            // Upgrade cases
            existingId == "cloud_12month" -> CHARGE_PRORATED_PRICE
            existingId == "plus_1month" && id == "plus_12month" -> CHARGE_PRORATED_PRICE
            // Downgrade case
            else -> DEFERRED
        }

        var expectId = id
        if (prorate == DEFERRED) {
            // Recent billing lib changes around DEFERRED mode report differently
            // https://developer.android.com/google/play/billing/subscriptions#handle-deferred-replacement
            expectId = existingId
            Logger.v("Billing", "Using prorate deferred mode")
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setSubscriptionUpdateParams(
                BillingFlowParams.SubscriptionUpdateParams.newBuilder()
                .setOldPurchaseToken(existingToken)
                .setSubscriptionReplacementMode(prorate)
                .build()
            )
            .setProductDetailsParamsList(listOf(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .setOfferToken(offerToken)
                .build()
            ))
            .build()
        val activity = context.requireActivity()
        val responseCode = getConnectedClient().launchBillingFlow(activity, flowParams).responseCode

        if (responseCode != BillingClient.BillingResponseCode.OK) {
            throw BlokadaException("changeProduct: error $responseCode")
        }

        return suspendCancellableCoroutine { cont ->
            ongoingPurchase = expectId to cont
        }
    }

    private fun Purchase.isActive(): Boolean {
        return when {
            purchaseState != Purchase.PurchaseState.PURCHASED -> false
            else -> false
        }
    }

    private fun getTrial(it: ProductDetails.SubscriptionOfferDetails): Long? {
        return when {
            it.offerTags.contains("free7") -> 7
            it.offerTags.contains("free14") -> 14
            it.offerTags.contains("freetrial") -> 14
            else -> null
        }
    }

    private fun getPeriodMonths(it: ProductDetails.PricingPhase): Int {
        return if (it.billingPeriod == "P1Y") 12 else 1
    }

    private fun getPricePerMonthString(it: ProductDetails.PricingPhase): String {
        val periodMonths = getPeriodMonths(it)
        val price = it.priceAmountMicros
        val perMonth = price / periodMonths
        return priceFormat.format(perMonth / 1_000_000f, it.priceCurrencyCode)
    }

    private fun getPriceString(it: ProductDetails.PricingPhase): String {
        return priceFormat.format(it.priceAmountMicros / 1_000_000f, it.priceCurrencyCode)
    }

    private val priceFormat = "%.2f %s"
}