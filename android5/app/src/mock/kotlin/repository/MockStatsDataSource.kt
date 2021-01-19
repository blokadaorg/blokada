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

package repository

import model.HistoryEntry
import model.HistoryEntryType
import java.util.*

object StatsDataSource {

    fun getHistory() = listOf(
        HistoryEntry(
            name = "doubleclick.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(5),
            requests = 45
        ),
        HistoryEntry(
            name = "google.com",
            type = HistoryEntryType.passed,
            time = Date().minus(7),
            requests = 1
        ),
        HistoryEntry(
            name = "example.com",
            type = HistoryEntryType.passed,
            time = Date().minus(8),
            requests = 1
        ),
        HistoryEntry(
            name = "a.example.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(12),
            requests = 3
        ),
        HistoryEntry(
            name = "b.example.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(12),
            requests = 2
        ),
        HistoryEntry(
            name = "a.doubleclick.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(15),
            requests = 42
        ),
        HistoryEntry(
            name = "b.doubleclick.com",
            type = HistoryEntryType.passed,
            time = Date().minus(30),
            requests = 1
        ),
        HistoryEntry(
            name = "c.doubleclick.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(3600),
            requests = 1
        ),
        HistoryEntry(
            name = "graph.facebook.com",
            type = HistoryEntryType.passed,
            time = Date().minus(3689),
            requests = 1
        ),
        HistoryEntry(
            name = "aa.facebook.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(3789),
            requests = 3
        ),
        HistoryEntry(
            name = "bb.facebook.com",
            type = HistoryEntryType.passed,
            time = Date().minus(3799),
            requests = 4
        ),
        HistoryEntry(
            name = "cc.facebook.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(3800),
            requests = 2
        ),
        HistoryEntry(
            name = "1.something.com",
            type = HistoryEntryType.passed,
            time = Date().minus(3900),
            requests = 12
        ),
        HistoryEntry(
            name = "very.long.name.of.the.domain.2.something.com",
            type = HistoryEntryType.blocked,
            time = Date().minus(10000),
            requests = 6
        ),
        HistoryEntry(
            name = "3.something.com",
            type = HistoryEntryType.passed,
            time = Date().minus(10001),
            requests = 1
        )
    )

}

fun Date.minus(minutes: Int): Date {
    return Date(time - minutes * 60 * 1000)
}

fun Date.plus(minutes: Int): Date {
    return Date(time + minutes * 60 * 1000)
}
