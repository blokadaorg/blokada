/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package model

typealias AccountId = String
typealias GatewayId = String
typealias PrivateKey = String
typealias PublicKey = String
typealias DeviceId = String

data class PaymentPayload(
    val purchase_token: String,
    val subscription_id: String,
    val user_initiated: Boolean
)

typealias Uri = String