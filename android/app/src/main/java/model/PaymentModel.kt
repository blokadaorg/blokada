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

package model

typealias ProductId = String
typealias UserInitiated = Boolean

data class Product(
        val id: ProductId,
        val title: String,
        val description: String,
        val price: String,
        val pricePerMonth: String,
        val periodMonths: Int,
        val type: String,
        val trial: Boolean,
        val owned: Boolean = false
)