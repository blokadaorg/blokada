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
import android.content.Intent
import androidx.core.app.ShareCompat
import androidx.core.content.FileProvider
import channel.tracer.TracerOps
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService
import java.io.File
import java.io.RandomAccessFile

object TracerBinding: TracerOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }

    init {
        TracerOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doStartFile(filename: String, template: String, callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, filename)
                file.writeText(template)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun doSaveBatch(
        filename: String,
        batch: String,
        mark: String,
        callback: (Result<Unit>) -> Unit
    ) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, filename)
                insertAtMarker(file, mark, batch)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    private fun insertAtMarker(file: File, marker: String, content: String) {
        if (marker.length != 3) throw Exception("Marker not 3 bytes long")

        val raf = RandomAccessFile(file, "rw")
        val markerBytes = marker.toByteArray(Charsets.UTF_8)
        val contentBytes = content.toByteArray(Charsets.UTF_8)
        var position = file.length() - markerBytes.size

        search@ while (position >= 0) {
            raf.seek(position)
            val bytes = ByteArray(markerBytes.size)
            raf.read(bytes, 0, markerBytes.size)
            for (i in markerBytes.indices) {
                if (bytes[i] != markerBytes[i]) {
                    position--
                    continue@search
                }
            }
            // If we're here, we've found the marker.
            break
        }

        if (position < 0) {
            raf.close()
            throw Exception("Marker not found")
        }

        // Read everything from the found position to the end of the file.
        raf.seek(position)
        val remaining = ByteArray((file.length() - position).toInt())
        raf.read(remaining)

        // Write the new content at the found position.
        raf.seek(position)
        raf.write(contentBytes)

        // Write the rest of the file back.
        raf.write(remaining)

        raf.close()
    }

    override fun doShareFile(filename: String, callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, filename)
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

    override fun doFileExists(filename: String, callback: (Result<Boolean>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, filename)
                callback(Result.success(file.exists()))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun doDeleteFile(filename: String, callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val file = File(context.requireAppContext().filesDir, filename)
                file.delete()
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
}