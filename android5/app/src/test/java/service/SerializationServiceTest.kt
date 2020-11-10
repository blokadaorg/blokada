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

package service

import model.HistoryEntry
import model.HistoryEntryType
import model.Stats
import org.junit.Test
import org.junit.Assert
import java.util.*

class SerializationServiceTest {
    @Test fun basic() {
        val stats = Stats(
            allowed = 1,
            denied = 2,
            entries = listOf(
                HistoryEntry(
                    name = "example.com",
                    type = HistoryEntryType.passed,
                    time = Date(),
                    requests = 1
                )
            )
        )

        val json = SerializationService.serialize(stats)
        val deserialized = SerializationService.deserialize(json, Stats::class)

        Assert.assertEquals(1, deserialized.allowed)
        Assert.assertEquals(2, deserialized.denied)
        Assert.assertEquals("example.com", deserialized.entries.first().name)
    }
}