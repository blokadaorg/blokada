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

package ui.stats

import model.Activity
import model.HistoryEntry
import model.HistoryEntryType
import repository.Repos
import service.EnvironmentService
import utils.toBlockaDate
import java.util.*

fun convertActivity(activity: List<Activity>): List<HistoryEntry> {
    val act = activity.map {
        HistoryEntry(
            name = it.domain_name,
            type = convertType(it),
            time = convertDate(it.timestamp),
            requests = 1,
            device = it.device_name,
            pack = getPack(it)
        )
    }

    // Group by name + type
    return act.groupBy { it.type to it.name }.map {
        // Assuming items are ordered by most recent first
        val item = it.value.first()
        HistoryEntry(
            name = item.name,
            type = item.type,
            time = item.time,
            requests = it.value.count(),
            device = item.device,
            pack = item.pack
        )
    }
}

private fun convertType(a: Activity): HistoryEntryType {
    return when {
        a.action == "block" && a.list == EnvironmentService.deviceTag -> HistoryEntryType.blocked_denied
        a.action == "allow" && a.list == EnvironmentService.deviceTag -> HistoryEntryType.passed_allowed
        a.action == "block" -> HistoryEntryType.blocked
        else -> HistoryEntryType.passed
    }
}

private fun convertDate(timestamp: String): Date {
    return timestamp.toBlockaDate()
}

private fun getPack(it: Activity): String? {
    // TODO: quite hacky
    if (it.list == EnvironmentService.deviceTag) return it.list
    return Repos.packs.getPackNameForBlocklist(it.list)
}