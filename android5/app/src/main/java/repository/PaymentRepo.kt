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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.*
import service.Services
import utils.Ignored
import utils.Logger
import utils.SimpleTasker
import utils.Tasker

class PaymentRepo {

    private val writeProducts = MutableStateFlow<List<Product>?>(null)
    private val writeSuccessfulPurchases = MutableSharedFlow<Pair<Account, UserInitiated>>()

    val productsHot = writeProducts.filterNotNull().distinctUntilChanged()
    val successfulPurchasesHot = writeSuccessfulPurchases

    private val refreshProductsT = SimpleTasker<Ignored>("refreshProducts")
    private val restorePurchaseT = SimpleTasker<Ignored>("restorePurchase")
    private val buyProductT = Tasker<ProductId, Ignored>("buyProduct", debounce = 0L, timeoutMs = 30000)
    private val changeProductT = Tasker<ProductId, Ignored>("changeProduct", debounce = 0L, timeoutMs = 30000)
    private val consumePurchaseT = Tasker<PaymentPayload, Ignored>("consumePurchase", debounce = 0L)

    private val processingRepo by lazy { Repos.processing }
    private val stageRepo by lazy { Repos.stage }
    private val accountRepo by lazy { Repos.account }

    private val api = Services.apiForCurrentUser
    private val payment = Services.payment

    fun start() {
        GlobalScope.launch { onRefreshProducts() }
        GlobalScope.launch { onBuyProduct() }
        GlobalScope.launch { onChangeProduct() }
        GlobalScope.launch { onRestorePurchase() }
        GlobalScope.launch { onConsumePurchase() }
        GlobalScope.launch { onStageChange_ObservePayments() }
        GlobalScope.launch { refreshProducts() } // Refresh products on init automatically
    }

    // Will ask google to refresh the products list used in the payments screen.
    suspend fun refreshProducts() {
        refreshProductsT.send()
    }

    suspend fun restorePurchase() {
        restorePurchaseT.send()
    }

    suspend fun buyProduct(productId: String) {
        buyProductT.send(productId)
    }

    suspend fun changeProduct(productId: String) {
        changeProductT.send(productId)
    }

    suspend fun cancelTransaction() {
        //self.storeKit.finishPurchase()
    }

    private suspend fun onRefreshProducts() {
        refreshProductsT.setTask {
            val products = payment.refreshProducts()
            writeProducts.emit(products)
            true
        }
    }

    private suspend fun onBuyProduct() {
        buyProductT.setTask {
            val payload = payment.buyProduct(it)
            consumePurchaseT.send(payload)
            true
        }
    }

    private suspend fun onChangeProduct() {
        changeProductT.setTask {
            val payload = payment.changeProduct(it)
            consumePurchaseT.send(payload)
            true
        }
    }

    private suspend fun onRestorePurchase() {
        restorePurchaseT.setTask {
            val payloads = payment.restorePurchase()
            var restored = false
            for (payload in payloads) {
                try {
                    Logger.v("Payment", "Trying to restore: ${payload.purchase_token}")
                    consumePurchaseT.send(payload)
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

    private suspend fun onConsumePurchase() {
        consumePurchaseT.setTask {
            // todo: info about ongoing purchase
            val account = api.postGplayCheckoutForCurrentUser(it)
            writeSuccessfulPurchases.emit(account to true)
            true
        }
    }

    private suspend fun onStageChange_ObservePayments() {

    }

}