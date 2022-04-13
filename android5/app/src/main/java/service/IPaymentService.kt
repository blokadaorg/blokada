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

import kotlinx.coroutines.delay
import model.Product
import model.ProductId
import utils.Logger

interface IPaymentService {
    suspend fun refreshProducts(): List<Product>
    suspend fun restorePurchase()
    suspend fun buyProduct(id: ProductId)
}

class PaymentServiceMock: IPaymentService {

    override suspend fun refreshProducts(): List<Product> {
        delay(2000)
        return listOf(
            Product(
                id = "cloud_12month",
                title = "", description = "",
                price = "$24.99",
                periodMonths = 12,
                type = "cloud",
                trial = true
            ),
            Product(
                id = "plus_1month",
                title = "", description = "",
                price = "$5.99",
                periodMonths = 1,
                type = "plus",
                trial = false
            ),
            Product(
                id = "plus_12month",
                title = "", description = "",
                price = "$39.99",
                periodMonths = 12,
                type = "plus",
                trial = false
            ),
        )
    }

    override suspend fun restorePurchase() {
        TODO("Not yet implemented")
    }

    override suspend fun buyProduct(id: ProductId) {
        Logger.v("xxxx", "Mock buying product: $id")
        delay(8000)
    }

}