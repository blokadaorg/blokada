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

    val stage by lazy { StageRepo() }
    val processing by lazy { DebugProcessingRepo() }
    val nav by lazy { NavRepo() }
    val cloud by lazy { CloudRepo() }
    val perms by lazy { PermsRepo() }
    val app by lazy { AppRepo() }
    val account by lazy { AccountRepo() }

    private var started = false

    fun start() {
        if (started) return
        started = true
        stage.start()
        processing.start()
        cloud.start()
        perms.start()
        app.start()
//        account.start()
    }

}