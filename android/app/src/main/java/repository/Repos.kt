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

package repository

object Repos {

    val processing by lazy { DebugProcessingRepo() }
    val perms by lazy { PermsRepo() }

    private var started = false

    fun start() {
        if (started) return
        started = true
        processing.start()
        perms.start()
    }

}