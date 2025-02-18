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
import androidx.core.app.ShareCompat
import service.ContextService

object ShareUtil {
    private val context by lazy { ContextService }

    fun shareText(text: String) {
        val ctx = context.requireContext()

        val activity = ctx as Activity
        val intent = ShareCompat.IntentBuilder.from(activity)
            .setType("text/plain")
            .setText(text)
            .createChooserIntent()
        ctx.startActivity(intent)
    }

    fun shareTextLegacy(text: String) {
        val openFileIntent = Intent(Intent.ACTION_SEND)
        // Flags left from sharing log file, not sure if needed
        openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        openFileIntent.type = "text/plain"
        openFileIntent.putExtra(Intent.EXTRA_TEXT, text)
        context.requireContext().startActivity(openFileIntent)
    }
}