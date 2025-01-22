/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.app.ShareCompat
import channel.family.FamilyOps
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService

// TODO: Include only in Family targets
object FamilyBinding: FamilyOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }

    init {
        FamilyOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doShareUrl(url: String, callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                shareUrl(url)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                try {
                    shareUrlLegacy(url)
                    callback(Result.success(Unit))
                } catch (ex: Exception) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    private fun shareUrl(url: String) {
        val ctx = context.requireContext()
        val uri = Uri.parse(url)

        val activity = ctx as Activity
        val intent = ShareCompat.IntentBuilder.from(activity)
            .setType("text/plain")
            .setText(uri.toString()) // Share the URL as text
            .createChooserIntent()
        ctx.startActivity(intent)
    }

    private fun shareUrlLegacy(url: String) {
        val openFileIntent = Intent(Intent.ACTION_SEND)
        // Flags left from sharing log file, not sure if needed
        openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        openFileIntent.type = "text/plain"
        openFileIntent.putExtra(Intent.EXTRA_TEXT, url)
        context.requireContext().startActivity(openFileIntent)
    }
}