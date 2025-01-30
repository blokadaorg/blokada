/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.core.app.ShareCompat
import androidx.core.content.FileProvider
import androidx.preference.PreferenceManager
import channel.core.CoreOps
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import model.BlokadaException
import model.LegacyAccount
import service.ContextService
import service.FlutterService
import service.JsonSerializationService
import service.PersistenceService
import utils.Logger
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.charset.Charset

object CoreBinding: CoreOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }

    private lateinit var fileName: String
    private val maxFileSize: Long = 5 * 1024 * 1024 // 5 MB
    private lateinit var logFile: File

    @Volatile
    private var currentSize: Long = 0

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val backedUpSharedPreferences by lazy {
        PreferenceManager.getDefaultSharedPreferences(context.requireContext())
    }

    private val localSharedPreferences by lazy {
        val ctx = context.requireContext()
        ctx.getSharedPreferences("local", Context.MODE_PRIVATE)
    }

    init {
        CoreOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    // Logger

    override fun doUseFilename(filename: String, callback: (Result<Unit>) -> Unit) {
        synchronized(this) {
            try {
                this.fileName = filename
                logFile = File(context.requireAppContext().filesDir, filename)
                currentSize = logFile.length()
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
    }

    override fun doSaveBatch(
        batch: String,
        callback: (Result<Unit>) -> Unit
    ) {
        scope.launch {
            synchronized(this@CoreBinding) {
                try {
                    RandomAccessFile(logFile, "rw").use { raf ->
                        raf.seek(raf.length())
                        val bytes = batch.toByteArray(Charset.forName("UTF-8"))
                        raf.write(bytes)
                        currentSize += bytes.size
                    }
                    trimLogFileIfNeeded()
                } catch (e: IOException) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun trimLogFileIfNeeded() {
        if (currentSize <= maxFileSize) return

        try {
            RandomAccessFile(logFile, "rw").use { raf ->
                // Define target size (e.g., 80% of max size)
                val targetSize = (maxFileSize * 0.8).toLong()
                val bytesToRemove = currentSize - targetSize

                var trimOffset = 0L
                var bytesRead = 0L
                val bufferSize = 4096 // 4 KB buffer
                val buffer = ByteArray(bufferSize)

                raf.seek(0)
                while (bytesRead < bytesToRemove) {
                    val startOffset = raf.filePointer
                    val read = raf.read(buffer)
                    if (read == -1) break // End of file

                    for (i in 0 until read) {
                        bytesRead++
                        if (buffer[i].toInt() == '\n'.toInt()) {
                            trimOffset = startOffset + i + 1
                        }
                    }
                }

                if (trimOffset > 0) {
                    // Calculate remaining bytes
                    val remainingLength = raf.length() - trimOffset
                    val remainingBytes = ByteArray(remainingLength.toInt())

                    raf.seek(trimOffset)
                    raf.readFully(remainingBytes)

                    // Truncate the file and write remaining bytes
                    raf.setLength(0)
                    raf.seek(0)
                    raf.write(remainingBytes)

                    currentSize = raf.length()
                }
            }
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    override fun doShareFile(callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, fileName)
                shareFile(file)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    private fun shareFile(file: File) {
        val ctx = context.requireContext()
        val actualUri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", file)

        val activity = ctx as? Activity
        if (activity != null) {
            val intent = ShareCompat.IntentBuilder.from(activity)
                .setStream(actualUri)
                .setType("text/*")
                .intent
                .setAction(Intent.ACTION_SEND)
                .setDataAndType(actualUri, "text/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        } else {
            val openFileIntent = Intent(Intent.ACTION_SEND)
            openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            openFileIntent.type = "plain/*"
            openFileIntent.putExtra(Intent.EXTRA_STREAM, actualUri)
            ctx.startActivity(openFileIntent)
        }
    }

    // Persistence

    override fun doSave(
        key: String,
        value: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        if (isBackup) {
            backedUpSharedPreferences.save(key, value)
        } else {
            localSharedPreferences.save(key, value)
        }
        callback(Result.success(Unit))
    }

    private fun SharedPreferences.save(key: String, value: String) {
        val edit = this.edit()
        edit.putString(key, value)
        edit.commit() || throw BlokadaException("Could not save $key to SharedPreferences")
    }

    override fun doLoad(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<String>) -> Unit
    ) {
        var result = if (isBackup) {
            backedUpSharedPreferences.getString(key, null)
        } else {
            localSharedPreferences.getString(key, null)
        }

        if (key == "account:jsonAccount") result = handleLegacyAccount(result)
        if (result != null) callback(Result.success(result))
        else callback(Result.failure(Exception("No value for key $key")))
    }

    override fun doDelete(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        if (isBackup) {
            backedUpSharedPreferences.edit().remove(key).commit()
        } else {
            localSharedPreferences.edit().remove(key).commit()
        }
        callback(Result.success(Unit))
    }

    // A temporary code to recover the account IDs saved in the old version of the app
    private val log = Logger("Legacy")
    private val legacyPersistence by lazy { PersistenceService }
    private val deserializer by lazy { JsonSerializationService }
    private fun handleLegacyAccount(json: String?): String? {
        var tryRecover = false
        if (json == null) tryRecover = true
        else {
            try {
                val acc = deserializer.deserialize(json, LegacyAccount::class)
                if (!acc.active) tryRecover = true
            } catch (e: Throwable) { }
        }

        if (tryRecover) {
            try {
                val acc = legacyPersistence.load(LegacyAccount::class)
                if (acc.active) {
                    log.v("Recovered legacy account")
                    val oldJson = deserializer.serialize(acc)
                    // To make sure one-time recovery
                    legacyPersistence.save(acc.copy(active = false))
                    return oldJson
                }
            } catch (e: Throwable) {}
        }

        return json
    }
}