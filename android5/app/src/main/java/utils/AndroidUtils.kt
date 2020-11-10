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

package ui.utils

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.util.Log
import android.util.TypedValue
import android.widget.Toast
import androidx.annotation.AttrRes
import androidx.annotation.ColorInt
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import model.SystemTunnelRevoked
import model.Uri
import org.blokada.R
import service.ContextService
import service.tr
import utils.Logger
import java.text.SimpleDateFormat
import java.util.*

object AndroidUtils {

    private val context = ContextService

    fun copyToClipboard(text: String) {
        val ctx = context.requireContext()
        val clipboard = ContextCompat.getSystemService(ctx, ClipboardManager::class.java)
        val clip = ClipData.newPlainText("name", text)
        clipboard?.setPrimaryClip(clip)
        Toast.makeText(ctx, ctx.getString(R.string.universal_status_copied_to_clipboard), Toast.LENGTH_SHORT).show()
    }

}

fun String.cause(ex: Throwable): String {
    return when (ex) {
        is SystemTunnelRevoked -> "$this: ${ex.localizedMessage}"
        else -> {
            val stacktrace = Log.getStackTraceString(ex)
            return "$this: ${ex.localizedMessage}\n$stacktrace"
        }
    }
}

@ColorInt
fun Context.getColorFromAttr(
    @AttrRes attrColor: Int,
    typedValue: TypedValue = TypedValue(),
    resolveRefs: Boolean = true
): Int {
    theme.resolveAttribute(attrColor, typedValue, resolveRefs)
    return typedValue.data
}

fun Fragment.getColor(colorResId: Int): Int {
    return ContextCompat.getColor(requireContext(), colorResId)
}

fun now() = System.currentTimeMillis()

fun openInBrowser(url: Uri) {
    try {
        val ctx = ContextService.requireContext()
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.data = android.net.Uri.parse(url)
        ctx.startActivity(intent)
    } catch (ex: Exception) {
        Logger.w("Browser", "Could not open url in browser: $url".cause(ex))
    }
}