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

package repository

import model.Packs
import model.Defaults
import utils.Logger

object PackMigration {

    fun migrate(packs: Packs): Pair<Packs, Boolean> {
        return if (packs.version ?: 0 < Defaults.PACKS_VERSION) {
            Logger.w("Pack", "Migrating packs from ${packs.version} to ${Defaults.PACKS_VERSION}")
            Packs(
                packs = Defaults.packs().packs.map { fresh ->
                    packs.packs.firstOrNull { persisted -> persisted.id == fresh.id }?.let { persisted ->
                        // Preserve PackStatus but adjust the selected configs to what actually exists now
                        fresh.copy(
                            status = persisted.status.copy(
                                config = persisted.status.config.intersect(fresh.configs).toList()
                            )
                        )
                    } ?: fresh
                },
                version = Defaults.PACKS_VERSION
            ) to true
        } else packs to false
    }
}