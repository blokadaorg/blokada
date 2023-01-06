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
 * depends on the useBackup flag. Same flag is used here to decide whether to backup the blocklist
 * files or not.
 */
class BackupAgent : BackupAgentHelper() {

    override fun onCreate() {
        ContextService.setAppContext(this.applicationContext)

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