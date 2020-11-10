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