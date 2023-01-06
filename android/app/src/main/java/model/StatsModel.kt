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
import engine.Host
import java.util.*

/**
 * Public structures used by other components.
 */

data class Stats(
    val allowed: Int,
    val denied: Int,
    val entries: List<HistoryEntry>
)

data class HistoryEntry(
    val name: String,
    val type: HistoryEntryType,
    val time: Date,
    val requests: Int,
    val device: String = "",
    val pack: String? = null
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

/**
 * Structures internal to StatsService used to persist the entries.
 */

@JsonClass(generateAdapter = true)
data class StatsPersisted(
    val entries: Map<String, StatsPersistedEntry>
)

@JsonClass(generateAdapter = true)
data class StatsPersistedKey(
    val host: Host,
    val type: HistoryEntryType
)

@JsonClass(generateAdapter = true)
class StatsPersistedEntry(
    var lastEncounter: Long,
    var occurrences: Int
)
