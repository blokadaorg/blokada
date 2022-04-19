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
import kotlinx.coroutines.*
import model.BlokadaException
import model.Product
import model.ProductId
import utils.Ignored
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

    private var ongoingPurchase: CancellableContinuation<Ignored>? = null
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
        Logger.w("Billing", "purchase reply: $billingResult")

        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (purchase in purchases) {
                Logger.w("Billing", "Purchase ok: $purchase")
                handlePurchase(purchase)
            }
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // Handle an error caused by a user cancelling the purchase flow.
            Logger.w("Billing", "User cancelled purchase")
            handlePurchase()
        } else {
            // Handle any other error codes.
            Logger.w("Billing", "Purchase error: $billingResult")
            handlePurchase()
        }
    }

    private fun handlePurchase(purchase: Purchase? = null) {
        // TODO: Handle PENDING purchase
        ongoingPurchase?.let { cont ->
            purchase?.let { purchase ->
                if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                    if (!purchase.isAcknowledged) {
                        val acknowledgePurchaseParams = AcknowledgePurchaseParams.newBuilder()
                            .setPurchaseToken(purchase.purchaseToken)
                        GlobalScope.launch {
                            val ackPurchaseResult = withContext(Dispatchers.IO) {
                                client.acknowledgePurchase(acknowledgePurchaseParams.build())
                            }
                            Logger.v("Billing", "ack result: $ackPurchaseResult")
                        }
                    }
                }
            }
            cont.resume(true, {})
            ongoingPurchase = null
        } ?: run {
            Logger.w("Billing", "There was no ongoing purchase")
        }
    }

    override suspend fun buyProduct(id: ProductId) {
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

        suspendCancellableCoroutine<Ignored> { cont ->
            ongoingPurchase = cont
        }
    }

    override suspend fun restorePurchase() {
        getConnectedClient().queryPurchasesAsync("subs") { billingResult, purchases ->
            TODO("Not yet implemented")
        }
    }

}