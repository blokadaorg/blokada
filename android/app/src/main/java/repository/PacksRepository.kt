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

}