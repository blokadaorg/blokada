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

import android.content.Context
import android.content.SharedPreferences
import androidx.preference.PreferenceManager
import model.BlokadaException
import model.LocalConfig
import ui.utils.cause
import utils.Logger
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.lang.Exception


interface StorageService {
    fun save(key: String, data: String)
    fun load(key: String): String?
}

object SharedPreferencesStorageService : StorageService {

    private val context = ContextService

    private val useBackup by lazy {
        // It's a stretch to use PersistenceService here and bad design, but since LocalConfig is
        // always saved to local preferences, it should be fine.
        val cfg = PersistenceService.load(LocalConfig::class)
        cfg.backup
    }

    private val backedUpSharedPreferences by lazy {
        PreferenceManager.getDefaultSharedPreferences(context.requireContext())
    }

    private val localSharedPreferences by lazy {
        val ctx = context.requireContext()
        ctx.getSharedPreferences("local", Context.MODE_PRIVATE)
    }

    override fun save(key: String, data: String) {
        val prefs = getSharedPreferences(key)
        prefs.save(key, data)

        // Also always save to local preferences in case user switches backup off
        if (prefs != localSharedPreferences) {
            localSharedPreferences.save(key, data)
        }
    }

    override fun load(key: String): String? {
        return getSharedPreferences(key).getString(key, null)
    }

    // Always use local source for some settings, or always backed up source for others
    private fun getSharedPreferences(key: String) = when (key) {
        "localConfig" -> localSharedPreferences
        "syncableConfig" -> backedUpSharedPreferences
        "account" -> backedUpSharedPreferences
        "networkSpecificConfigs" -> localSharedPreferences // Not send network names anywhere
        else -> if (useBackup) backedUpSharedPreferences else localSharedPreferences
    }

    private fun SharedPreferences.save(key: String, value: String) {
        val edit = this.edit()
        edit.putString(key, value)
        edit.commit() || throw BlokadaException("Could not save $key to SharedPreferences")
    }

}


object FileStorageService : StorageService {

    private val file = FileService

    override fun save(key: String, data: String) {
        val path = file.commonDir().file(key)
        val destination = FileOutputStream(path)
        val outputStreamWriter = OutputStreamWriter(destination)
        outputStreamWriter.write(data)
        outputStreamWriter.close()
    }

    override fun load(key: String): String? {
        val path = file.commonDir().file(key)
        val source = FileInputStream(path)
        val inputStreamReader = InputStreamReader(source)
        try {
            return inputStreamReader.readText()
        } catch (ex: Exception) {
            Logger.e("Storage", "Could not read file: $key".cause(ex))
            return null
        } finally {
            inputStreamReader.close()
        }
    }

}