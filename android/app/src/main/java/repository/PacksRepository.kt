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

import model.*
import model.Defaults
import model.Defaults.PACKS_VERSION
import service.PersistenceService

class PacksRepository {

    private val persistence = PersistenceService

//    private var packs = persistence.load(Packs::class)
    private var packs = Defaults.packs()
        set(value) {
            field = value
            persistence.save(value)
        }

    fun getPacks() = packs.packs

    fun getPack(packId: PackId): Pack {
        return packs.packs.first { it.id == packId }
    }

    fun updatePack(pack: Pack) {
        packs = Packs(
            packs = packs.packs.map { if (it == pack) pack else it },
            version = PACKS_VERSION
        )
    }

}