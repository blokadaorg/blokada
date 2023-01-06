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

import com.squareup.moshi.JsonClass

typealias AppId = String

class App(
    val id: AppId,
    val name: String,
    val isBypassed: Boolean,
    val isSystem: Boolean
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as App

        if (id != other.id) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }
}

@JsonClass(generateAdapter = true)
class BypassedAppIds(
    val ids: List<AppId>
)

enum class AppState {
    Deactivated, Paused, Activated
}