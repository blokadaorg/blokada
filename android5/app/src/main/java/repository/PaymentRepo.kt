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

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.*
import service.Services
import utils.Ignored
import utils.Logger
import utils.SimpleTasker
import utils.Tasker

class PaymentRepo {

    private val writeProducts = MutableSharedFlow<List<Product>?>(replay = 1)
    private val writeSuccessfulPurchases = MutableSharedFlow<Pair<Account, UserInitiated>>()
    private val writeActiveSub = MutableSharedFlow<ProductId?>(replay = 1)

    val productsHot = writeProducts.filterNotNull()
    val successfulPurchasesHot = writeSuccessfulPurchases
    val activeSubHot = writeActiveSub.distinctUntilChanged()

    private val refreshProductsT = SimpleTasker<Ignored>("refreshProducts")
    private val refreshPurchasesT = SimpleTasker<Ignored>("refreshPurchases")
    private val restorePurchaseT = SimpleTasker<Ignored>("restorePurchase")
    private val buyProductT = Tasker<ProductId, Ignored>("buyProduct", debounce = 0L, timeoutMs = 60000)
    private val changeProductT = Tasker<ProductId, Ignored>("changeProduct", debounce = 0L, timeoutMs = 30000)
    private val consumePurchaseT = Tasker<PaymentPayload, Ignored>("consumePurchase", debounce = 0L)

    private val accountRepo by lazy { Repos.account }

    private val api = Services.apiForCurrentUser
    private val payment = Services.payment

    fun start() {
        onRefreshProducts()
        onRefreshPurchases()
        onBuyProduct()
        onChangeProduct()
        onRestorePurchase()
        onConsumePurchase()
        onStageChange_ObservePayments()
        //refreshQuietly() // Refresh products on init automatically
    }

    // Will ask google to refresh the products list used in the payments screen.
    suspend fun refresh() {
        refreshProductsT.get()
        refreshPurchasesT.get()
    }

    private fun refreshQuietly() {
        GlobalScope.launch {
            refreshProductsT.send()
            refreshPurchasesT.send()
        }
    }

    suspend fun restorePurchase() {
        restorePurchaseT.get()
    }

    suspend fun buyProduct(productId: String) {
        buyProductT.get(productId)
    }

    suspend fun changeProduct(productId: String) {
        changeProductT.get(productId)
    }

    suspend fun cancelTransaction() {
        //self.storeKit.finishPurchase()
    }

    private fun onRefreshProducts() {
        refreshProductsT.setTask {
            try {
                val products = payment.refreshProducts()
                writeProducts.emit(products)
            } catch (ex: Exception) {
                writeProducts.emit(emptyList())
                throw ex
            }
            true
        }

        refreshProductsT.setOnError {
            writeProducts.emit(emptyList())
            throw NoPayments()
        }
    }

    private fun onRefreshPurchases() {
        refreshPurchasesT.setTask {
            try {
                val purchase = payment.getActivePurchase()
                writeActiveSub.emit(purchase)
            } catch (ex: Exception) {
                writeActiveSub.emit(null)
                throw ex
            }
            true
        }

        refreshPurchasesT.setOnError {
            writeActiveSub.emit(null)
        }
    }

    private fun onBuyProduct() {
        buyProductT.setTask {
            val payload = payment.buyProduct(it)
            consumePurchaseT.get(payload)
        }
    }

    private fun onChangeProduct() {
        changeProductT.setTask {
            try {
                val payload = payment.changeProduct(it)
                consumePurchaseT.get(payload)
            } catch (ex: NoRelevantPurchase) {
                // We catch this as in the upgrade flow the purchase doesn't come instant, because of
                // the prorate mode. It'll arrive to backend once the current subscription ends and
                // the subscription changes.
                Logger.w("Payment", "No relevant purchase in upgrade flow, ignoring")
                val account = accountRepo.accountHot.first()
                writeSuccessfulPurchases.emit(account to true)
            }
            true
        }
    }

    private fun onRestorePurchase() {
        restorePurchaseT.setTask {
            val payloads = payment.restorePurchase()
            var restored = false
            for (payload in payloads) {
                try {
                    Logger.v("Payment", "Trying to restore: ${payload.purchase_token}")
                    consumePurchaseT.get(payload)
                    restored = true
                    break
                } catch (ex: Exception) {
                    Logger.w("Payment", "Backend did not restore purchase, moving on")
                    Logger.v("Payment", "$payload")
                }
            }

            if (!restored) throw BlokadaException("Could not restore purchase")
            true
        }
    }

    private fun onConsumePurchase() {
        consumePurchaseT.setTask {
            // todo: info about ongoing purchase
            val account = api.postGplayCheckoutForCurrentUser(it)
            writeSuccessfulPurchases.emit(account to true)
            true
        }
    }

    private fun onStageChange_ObservePayments() {

    }

}