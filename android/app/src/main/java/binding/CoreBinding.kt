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
import service.SecureStorageService
import utils.Intents
import utils.Logger
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.charset.Charset
import androidx.core.content.edit
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

object CoreBinding : CoreOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }
    private val intents by lazy { Intents }

    private lateinit var fileName: String
    private val maxFileSize: Long = 5 * 1024 * 1024 // 5 MB
    private lateinit var logFile: File

    @Volatile
    private var currentSize: Long = 0

    private val scope = CoroutineScope(SupervisorJob())
    private val mutex = Mutex()
    // Log writes and the tail read run one at a time in the order they were
    // submitted, so a read sees every batch queued before it.
    private val logIo = Dispatchers.IO.limitedParallelism(1)

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
                callback(Result.success(Unit))
            } catch (e: IOException) {
                e.printStackTrace()
                callback(Result.failure(e))
            }
        }
    }

    override fun doSaveBatch(
        batch: String,
        callback: (Result<Unit>) -> Unit
    ) {
        scope.launch(logIo) {
            val result = mutex.withLock {
                try {
                    RandomAccessFile(logFile, "rw").use { raf ->
                        raf.seek(raf.length())
                        val bytes = batch.toByteArray(Charset.forName("UTF-8"))
                        raf.write(bytes)
                        currentSize += bytes.size
                    }
                    trimLogFileIfNeeded()
                    Result.success(Unit)
                } catch (e: IOException) {
                    e.printStackTrace()
                    Result.failure(e)
                }
            }
            withContext(Dispatchers.Main) {
                callback(result)
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

    // Runs on logIo after every batch queued before it, so they are in the tail.
    override fun doReadLogTail(maxBytes: Long, callback: (Result<String>) -> Unit) {
        scope.launch(logIo) {
            val result = mutex.withLock {
                // Any failure must still reach the callback, or the chat
                // waits on the upload forever.
                try {
                    Result.success(readLogTail(maxBytes))
                } catch (e: Exception) {
                    e.printStackTrace()
                    Result.failure(e)
                }
            }
            withContext(Dispatchers.Main) {
                callback(result)
            }
        }
    }

    // The support chat uploads only the end of the log, which its server caps.
    // A cut file starts after the first newline, so it opens with a whole line
    // and never inside a multi-byte character.
    private fun readLogTail(maxBytes: Long): String {
        if (!::logFile.isInitialized || !logFile.exists()) return ""
        RandomAccessFile(logFile, "r").use { raf ->
            val length = raf.length()
            val start = maxOf(0L, length - maxBytes)
            val bytes = ByteArray((length - start).toInt())
            raf.seek(start)
            raf.readFully(bytes)
            val from = if (start == 0L) 0 else bytes.indexOf('\n'.code.toByte()) + 1
            return String(bytes, from, bytes.size - from, Charsets.UTF_8)
        }
    }

    // This is for log sharing only
    override fun doShareFile(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                val file = File(context.requireAppContext().filesDir, fileName)
                val ctx = context.requireContext()
                val intent = intents.createShareFileIntent(ctx, file)
                intents.openIntentActivity(ctx, intent)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    // Persistence
    //
    // Secure values are encrypted with a Keystore key (SecureStorageService)
    // and never written to the plain preferences. Older versions kept them
    // there, so a secure read that finds nothing encrypted moves a plain
    // value over and deletes it. Secure values that are also backed up (the
    // account) get a Block Store copy, which brings them back on a reinstall
    // or a new phone.

    private val secure by lazy { SecureStorageService }
    private val storageLog = Logger("Storage")

    // Block Store calls run one at a time in the order they were made, so a
    // delete followed by a save (a replaced account) cannot land reversed.
    private val blockStoreIo = Dispatchers.IO.limitedParallelism(1)
    private val blockStoreMutex = Mutex()

    private fun inBlockStore(block: suspend () -> Unit) {
        scope.launch(blockStoreIo) { blockStoreMutex.withLock { block() } }
    }

    override fun doSave(
        key: String,
        value: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            if (isSecure) {
                secure.save(key, value)
                removePlain(key)
                if (isBackup) inBlockStore { secure.saveToBlockStore(key, value) }
            } else if (isBackup) {
                backedUpSharedPreferences.save(key, value)
            } else {
                localSharedPreferences.save(key, value)
            }
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
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
        if (!isSecure) {
            var result = if (isBackup) {
                backedUpSharedPreferences.getString(key, null)
            } else {
                localSharedPreferences.getString(key, null)
            }
            if (key == "account:jsonAccount") result = handleLegacyAccount(result)
            if (result != null) callback(Result.success(result))
            else callback(Result.failure(Exception("No value for key $key")))
            return
        }

        scope.launch(Dispatchers.IO) {
            var result = loadSecure(key, isBackup)
            if (key == "account:jsonAccount") result = handleLegacyAccount(result)
            withContext(Dispatchers.Main) {
                if (result != null) callback(Result.success(result))
                else callback(Result.failure(Exception("No value for key $key")))
            }
        }
    }

    private suspend fun loadSecure(key: String, isBackup: Boolean): String? {
        secure.load(key)?.let { return it }

        val plain = (if (isBackup) backedUpSharedPreferences else localSharedPreferences)
            .getString(key, null)
        if (plain != null) {
            storageLog.v("Moving $key to secure storage")
            storeLocally(key, plain, removePlain = true)
            if (isBackup) inBlockStore { secure.saveToBlockStore(key, plain) }
            return plain
        }

        if (!isBackup) return null
        val restored = withContext(blockStoreIo) {
            blockStoreMutex.withLock { secure.loadFromBlockStore(key) }
        } ?: return null
        storageLog.v("Restored $key from Block Store")
        storeLocally(key, restored, removePlain = false)
        return restored
    }

    // A failed write leaves the plain copy in place, so the value is not lost
    // and the move is tried again on the next read.
    private fun storeLocally(key: String, value: String, removePlain: Boolean) {
        try {
            secure.save(key, value)
            if (removePlain) removePlain(key)
        } catch (e: Exception) {
            storageLog.w("Could not save $key to secure storage: ${e.message}")
        }
    }

    // Older versions could have a copy in either file.
    private fun removePlain(key: String) {
        backedUpSharedPreferences.edit(commit = true) { remove(key) }
        localSharedPreferences.edit(commit = true) { remove(key) }
    }

    override fun doDelete(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        if (isSecure) {
            secure.delete(key)
            removePlain(key)
            if (isBackup) inBlockStore { secure.deleteFromBlockStore(key) }
        } else if (isBackup) {
            backedUpSharedPreferences.edit(commit = true) { remove(key) }
        } else {
            localSharedPreferences.edit(commit = true) { remove(key) }
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
            } catch (e: Throwable) {
            }
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
            } catch (e: Throwable) {
            }
        }

        return json
    }
}