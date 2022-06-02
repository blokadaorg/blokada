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

data class ComponentError(
    val component: String,
    val error: BlokadaException,
    val major : Boolean
)

data class ComponentOngoing(
    val component: String,
    val ongoing: Boolean
) {
    override fun toString(): String {
        return component
    }
}

data class ComponentTimeout(
    val component: String,
    val timeoutMillis: Long
) {
    override fun toString(): String {
        return "$component: $timeoutMillis"
    }
}
