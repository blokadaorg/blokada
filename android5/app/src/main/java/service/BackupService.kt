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

import android.app.backup.*
import android.os.ParcelFileDescriptor
import model.LocalConfig
import utils.Logger

private val log = Logger("Backup")

object BackupService {

    var onBackupRestored = {}

    fun requestBackup() {
        log.v("Requesting backup")
        val ctx = ContextService.requireAppContext()
        val manager = BackupManager(ctx)
        manager.dataChanged()
    }

}

/**
 * This will back up the following things:
 * - All settings saved in the default shared preferences namespace
 * - Blocklist files (merged blocklist, allowed list and denied list)
 *
 * What is saved to the default shared preferences namespace is controlled by PersistenceService, and
 * depends on the useBackup flag. Same flag is used here to decide wether to backup the blocklist
 * files or not.
 */
class BackupAgent : BackupAgentHelper() {

    override fun onCreate() {
        ContextService.setContext(this)

        log.v("Registering backup agent")

        // This is taken from the SharedPreferences source code, there's no api for this
        val sharedPreferencesFileName = packageName + "_preferences"

        addHelper(sharedPreferencesFileName,
            SharedPreferencesBackupHelper(this, sharedPreferencesFileName)
        )

        val useBackup = PersistenceService.load(LocalConfig::class).backup

        if (useBackup) {
            log.v("Registering blocklist file backup")
            addHelper(
                BlocklistService.MERGED_BLOCKLIST,
                FileBackupHelper(this, BlocklistService.MERGED_BLOCKLIST)
            )

            addHelper(
                BlocklistService.USER_ALLOWED,
                FileBackupHelper(this, BlocklistService.USER_ALLOWED)
            )

            addHelper(
                BlocklistService.USER_DENIED,
                FileBackupHelper(this, BlocklistService.USER_DENIED)
            )
        }
    }

    override fun onBackup(oldState: ParcelFileDescriptor?, data: BackupDataOutput?,
                          newState: ParcelFileDescriptor?) {
        log.v("Backing up")
        super.onBackup(oldState, data, newState)
    }

    override fun onRestore(data: BackupDataInput?, appVersionCode: Int, newState: ParcelFileDescriptor?) {
        super.onRestore(data, appVersionCode, newState)
        log.v("Restoring backup")
        BackupService.onBackupRestored()
    }

}