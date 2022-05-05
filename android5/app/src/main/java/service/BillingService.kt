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

import com.android.billingclient.api.*
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import model.BlokadaException
import model.PaymentPayload
import model.Product
import model.ProductId
import utils.Logger
import kotlin.coroutines.resumeWithException

class BillingService: IPaymentService {

    private val context by lazy { Services.context }

    private lateinit var client: BillingClient
    private var connected = false
        @Synchronized set
        @Synchronized get

    private var latestSkuList: List<SkuDetails> = emptyList()
        @Synchronized set
        @Synchronized get

    private var ongoingPurchase: Pair<ProductId, CancellableContinuation<PaymentPayload>>? = null
        @Synchronized set
        @Synchronized get

    override suspend fun setup() {
        client = BillingClient.newBuilder(context.requireAppContext())
            .setListener(purchaseListener)
            .enablePendingPurchases()
            .build()
    }

    private suspend fun getConnectedClient(): BillingClient {
        if (connected) return client
        return suspendCancellableCoroutine<BillingClient> { cont ->
            client.startConnection(object : BillingClientStateListener {

                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        connected = true
                        cont.resume(client) {
                            Logger.w("Billing", "Cancelled getConnectedClient()")
                        }
                    } else {
                        connected = false
                        cont.resumeWithException(
                            BlokadaException(
                                "onBillingSetupFinished returned wrong result: $billingResult"
                            )
                        )
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
        val skuList = ArrayList<String>()
        skuList.add("cloud_12month")
        skuList.add("plus_month")
        skuList.add("plus_12month")
        val params = SkuDetailsParams.newBuilder()
        params.setSkusList(skuList).setType(BillingClient.SkuType.SUBS)

        val skuDetailsResult = withContext(Dispatchers.IO) {
            getConnectedClient().querySkuDetails(params.build())
        }

        latestSkuList = skuDetailsResult.skuDetailsList ?: emptyList()
        return skuDetailsResult.skuDetailsList?.map {
            Product(
                id = it.sku,
                title = it.title,
                description = it.description,
                price = it.price,
                pricePerMonth = it.price, // TODO
                periodMonths = if (it.subscriptionPeriod == "P1Y") 12 else 1,
                type = if(it.sku.startsWith("cloud")) "cloud" else "plus",
                trial = it.freeTrialPeriod.isNotBlank()
            )
        } ?: emptyList()
    }

    private val purchaseListener = PurchasesUpdatedListener { billingResult, purchases ->
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            ongoingPurchase?.let { c ->
                val (productId, cont) = c
                val purchase = purchases
                    .sortedByDescending { it.purchaseTime }
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .firstOrNull { it.skus.firstOrNull() == productId }

                if (purchase == null) {
                    cont.resumeWithException(BlokadaException("Found no relevant purchase"))
                } else {
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
            Logger.v("Billing", "User cancelled purchase")
            ongoingPurchase?.second?.resumeWithException(UserCancelledException())
        } else {
            // Handle any other error codes.
            Logger.w("Billing", "Purchase error: $billingResult")
            val exception = if (billingResult.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                AlreadyPurchasedException()
            } else BlokadaException("Purchase error: $billingResult")

            ongoingPurchase?.second?.resumeWithException(exception)
        }
        ongoingPurchase = null
    }

    override suspend fun buyProduct(id: ProductId): PaymentPayload {
        val skuDetails = latestSkuList.firstOrNull { it.sku == id } ?:
            throw BlokadaException("Unknown product ID")

        val flowParams = BillingFlowParams.newBuilder()
            .setSkuDetails(skuDetails)
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
        getConnectedClient().queryPurchasesAsync("subs") { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                val successfulPurchases = purchases
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .sortedByDescending { it.purchaseTime }

                if (successfulPurchases.isNotEmpty()) {
                    Logger.v("Billing", "Restoring ${successfulPurchases.size} purchases")
                    ongoingRestore?.resume(successfulPurchases.map {
                        PaymentPayload(
                            purchase_token = it.purchaseToken,
                            subscription_id = it.skus.first(),
                            user_initiated = false
                        )
                    }, {})
                } else {
                    ongoingRestore?.resumeWithException(
                        BlokadaException("Restoring purchase found no successful purchases: $billingResult")
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

}