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
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.*
import service.Services
import utils.Ignored
import utils.SimpleTasker
import utils.Tasker
import java.util.*

class PaymentRepo {

    private val writeProducts = MutableStateFlow<List<Product>?>(null)
    private val writeSuccessfulPurchases = MutableStateFlow<Pair<Account, UserInitiated>?>(null)

    val productsHot = writeProducts.filterNotNull().distinctUntilChanged()
    val successfulPurchasesHot = writeSuccessfulPurchases

    private val refreshProductsT = SimpleTasker<Ignored>("refreshProducts")
    private val restorePurchaseT = SimpleTasker<Ignored>("restorePurchase")
    private val buyProductT = Tasker<ProductId, Ignored>("buyProduct")
    private val consumePurchaseT = Tasker<UserInitiated, Ignored>("consumePurchase", debounce = 0L)

    private val processingRepo by lazy { Repos.processing }
    private val stageRepo by lazy { Repos.stage }
    private val accountRepo by lazy { Repos.account }

    private val api = Services.apiForCurrentUser
    private val payment = Services.payment

    fun start() {
        GlobalScope.launch { onRefreshProducts() }
        GlobalScope.launch { onBuyProduct() }
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
            payment.buyProduct(it)
            consumePurchaseT.send(true)
            true
        }
    }

    private suspend fun onRestorePurchase() {
        restorePurchaseT.setTask {
            throw BlokadaException("restore purchase ot implemented yet")
            true
        }
    }

    private suspend fun onConsumePurchase() {
        consumePurchaseT.setTask {
            // todo: info about ongoing purchase
            // todo: verify with backend here
            delay(1000)
            val account = Account(
                id = "mockedmocked",
                active_until = Date(Date().time + 6000),
                active = true,
                type = "cloud"
            )
            writeSuccessfulPurchases.emit(account to true)

            // MutableStateFlow remembers latest value.
            // Emit null to not confuse future subscribers.
            // Delay to avoid state conflation.
            delay(1000)
            writeSuccessfulPurchases.emit(null)
            true
        }
    }

    private suspend fun onStageChange_ObservePayments() {

    }

}