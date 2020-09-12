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

import android.app.backup.BackupAgentHelper
import android.app.backup.BackupManager
import android.app.backup.SharedPreferencesBackupHelper
import utils.Logger

private val log = Logger("Backup")

object BackupService {

    fun requestBackup() {
        log.v("Requesting backup")
        val ctx = ContextService.requireAppContext()
        val manager = BackupManager(ctx)
        manager.dataChanged()
    }

}

class BackupAgent : BackupAgentHelper() {

    override fun onCreate() {
        ContextService.setContext(this)

        log.v("Registering backup agent")

        // This is taken from the SharedPreferences source code, there's no api for this
        val sharedPreferencesFileName = packageName + "_preferences"

        addHelper(sharedPreferencesFileName,
            SharedPreferencesBackupHelper(this, sharedPreferencesFileName)
        )
    }

}