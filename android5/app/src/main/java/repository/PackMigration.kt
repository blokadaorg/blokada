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
                version = Defaults.PACKS_VERSION,
                lastRefreshMillis = 0L // Force re-download
            ) to true
        } else packs to false
    }
}