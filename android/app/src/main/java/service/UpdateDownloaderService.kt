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

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Environment
import androidx.core.content.FileProvider
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.BlokadaException
import model.Uri
import ui.Command
import ui.executeCommand
import ui.utils.cause
import utils.Logger
import java.io.File

object UpdateDownloaderService {

    private val log = Logger("Downloader")
    private val scope = GlobalScope

    private val ctx by lazy {
        // This is not a leak because it's just app context
        ContextService.requireAppContext()
    }

    private val dm by lazy { ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager }

    fun installUpdate(links: List<Uri>, onFinished: (Boolean) -> Unit) {
        scope.launch {
            try {
                val apk = downloadUpdate(links)
                openInstall(apk)
                onFinished(true)
            } catch (ex: Exception) {
                log.e("Could not open apk to install, ignoring".cause(ex))
                onFinished(false)
            }
        }
    }

    fun cancelUpdate() {
        ongoingDownload?.let {
            log.w("Cancelling update")
            val (_, downloadId) = it
            dm.remove(downloadId)
            ongoingDownload = null
        }
    }

    private suspend fun downloadUpdate(links: List<Uri>): Uri {
        for (link in links) {
            try {
                log.v("Attempting to download update: $link")
                return download(link).await()
            } catch (ex: Exception) {
                log.e("Could not download update link".cause(ex))
            }
        }

        throw BlokadaException("No download link worked")
    }

    private fun openInstall(uri: Uri) {
        log.v("Attempting to open install: $uri")
        val openFileIntent = Intent(Intent.ACTION_VIEW).also {
            it.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            it.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            it.data = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", File(uri.removePrefix("file://")))
        }
        ctx.startActivity(openFileIntent)
    }

//    private fun getDownloadPercentage(): Int {
//        if (downloadId == null) return DOWNLOAD_COMPLETE
//
//        val query = DownloadManager.Query()
//        query.setFilterById(downloadId!!)
//        val c = dm.query(query)
//        if (c.moveToFirst()) {
//            val bytes_downloaded = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
//            val bytes_total = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
//            return ((bytes_downloaded / bytes_total.toFloat()) * 100).toInt()
//        } else return DOWNLOAD_FAIL
//    }
//
//    private fun monitorDownloadProgress() = async {
//        var downloading = true
//        while (downloading) {
//            delay(2000)
//            async(UI) {
//                val progress = getDownloadPercentage()
//                emit(EVENT_UPDATE_PROGRESS, progress)
//                if (progress in listOf(DOWNLOAD_FAIL, DOWNLOAD_COMPLETE)) downloading = false
//            }
//        }
//    }

    private fun download(uri: Uri): DownloadDeferred {
        val deferred = CompletableDeferred<Uri>()

        removePreviousDownload()

        val request = DownloadManager.Request(android.net.Uri.parse(uri))
        request.setDestinationInExternalFilesDir(ctx, null, DOWNLOAD_FILENAME)

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                ongoingDownload?.let {
                    val (receiver, downloadId) = it
                    ctx.unregisterReceiver(receiver)
                    ongoingDownload = null

                    if (DownloadManager.ACTION_DOWNLOAD_COMPLETE == intent.action) {
                        val query = DownloadManager.Query()
                        query.setFilterById(downloadId)
                        val c = dm.query(query)
                        if (c.moveToFirst()) {
                            val columnIndex = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                            if (DownloadManager.STATUS_SUCCESSFUL == c.getInt(columnIndex)) {
                                val uriString = c.getString(c.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI))
                                deferred.complete(uriString)
                            } else {
                                deferred.completeExceptionally(BlokadaException("Download failed"))
                            }
                        }
                    }
                } ?: log.w("BroadcastReceiver called for an unknown download, ignoring")
            }
        }

        ctx.registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        val downloadId = dm.enqueue(request)
        ongoingDownload = receiver to downloadId
        return deferred
    }

    private fun removePreviousDownload() {
        try {
            ctx.getExternalFilesDir(DOWNLOAD_FILENAME)?.let {
                if (it.exists()) {
                    log.v("Removing previous download")
                    it.delete()
                }
            }
        } catch (ex: Exception) {
            log.w("Could not remove previous download".cause(ex))
        }
    }

    private var ongoingDownload: Pair<BroadcastReceiver, DownloadId>? = null

}

private typealias DownloadDeferred = CompletableDeferred<Uri>
private typealias DownloadId = Long

private const val DOWNLOAD_FILENAME = "blokada-update.apk"