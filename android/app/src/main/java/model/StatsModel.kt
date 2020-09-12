/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package model

import androidx.lifecycle.GeneratedAdapter
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import java.util.*

@JsonClass(generateAdapter = true)
data class Stats(
    val allowed: Int,
    val denied: Int,
    val entries: List<HistoryEntry>
)

@JsonClass(generateAdapter = true)
data class HistoryEntry(
    val name: String,
    val type: HistoryEntryType,
    val time: Date,
    val requests: Int
)

enum class HistoryEntryType {
    blocked,
    passed,
    passed_allowed, // Passed because its on user Allowed list
    blocked_denied, // Blocked because its on user Denied list
}

@JsonClass(generateAdapter = true)
data class Allowed(val value: List<String>) {

    fun allow(name: String) = when (name) {
        in value -> this
        else -> Allowed(value = value + name)
    }

    fun unallow(name: String) = when (name) {
        in value -> Allowed(value = value - name)
        else -> this
    }

}

@JsonClass(generateAdapter = true)
data class Denied(val value: List<String>) {

    fun deny(name: String) = when (name) {
        in value -> this
        else -> Denied(value = value + name)
    }

    fun undeny(name: String) = when (name) {
        in value -> Denied(value = value - name)
        else -> this
    }

}

@JsonClass(generateAdapter = true)
data class AdsCounter(
    val persistedValue: Long,
    val runtimeValue: Long = 0
) {
    fun get() = persistedValue + runtimeValue
    fun roll() = AdsCounter(persistedValue = persistedValue + runtimeValue)
}
