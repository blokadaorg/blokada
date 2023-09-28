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

import com.squareup.moshi.JsonClass

enum class AccountType {
    Libre, Cloud, Plus
}

fun String?.toAccountType(): AccountType {
    return when (this) {
        "cloud" -> AccountType.Cloud
        "plus" -> AccountType.Plus
        else -> AccountType.Libre
    }
}

fun AccountType.isActive() = this != AccountType.Libre

@JsonClass(generateAdapter = true)
data class LegacyAccount(
    val id: AccountId,
    val active: Boolean
)