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

import channel.accountpayment.Product
import kotlinx.coroutines.delay
import model.PaymentPayload
import model.ProductId

interface IPaymentService {
    suspend fun setup()
    suspend fun refreshProducts(): List<Product>
    suspend fun restorePurchase(): List<PaymentPayload>
    suspend fun buyProduct(id: ProductId): PaymentPayload
    suspend fun changeProduct(id: ProductId): PaymentPayload
    suspend fun getActivePurchase(): ProductId?
}

class PaymentServiceMock: IPaymentService {

    override suspend fun setup() {}

    override suspend fun refreshProducts(): List<Product> {
        delay(2000)
        return listOf(
            Product(
                id = "cloud_12month",
                title = "", description = "",
                price = "$24.99",
                pricePerMonth = "$2.09",
                periodMonths = 12,
                type = "cloud",
                trial = 7,
                owned = false
            ),
            Product(
                id = "plus_1month",
                title = "", description = "",
                price = "$5.99",
                pricePerMonth = "$5.99",
                periodMonths = 1,
                type = "plus",
                trial = null,
                owned = false
            ),
            Product(
                id = "plus_12month",
                title = "", description = "",
                price = "$39.99",
                pricePerMonth = "$3.33",
                periodMonths = 12,
                type = "plus",
                trial = null,
                owned = false
            ),
        )
    }

    override suspend fun restorePurchase(): List<PaymentPayload> {
        TODO("Not yet implemented")
    }

    override suspend fun buyProduct(id: ProductId): PaymentPayload {
        delay(8000)
        return PaymentPayload(
            purchase_token = "mocked",
            subscription_id = id,
            user_initiated = true
        )
    }

    override suspend fun changeProduct(id: ProductId): PaymentPayload {
        TODO("Not yet implemented")
    }

    override suspend fun getActivePurchase(): ProductId? {
        TODO("Not yet implemented")
    }

}