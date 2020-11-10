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

import android.app.AlertDialog
import android.content.DialogInterface
import android.widget.TextView
import android.graphics.Typeface
import android.widget.Toast
import org.blokada.R
import utils.Logger

object AlertDialogService {

    private val log = Logger("Dialog")
    private val context = ContextService

    private var displayedDialog: AlertDialog? = null

    fun showAlert(
        message: Int,
        title: Int? = null,
        onDismiss: () -> Unit = {},
        additionalAction: Pair<String, () -> Unit>? = null
    ) {
        val ctx = context.requireContext()
        showAlert(
            message = ctx.getString(message),
            title = title?.let { ctx.getString(it) },
            onDismiss = onDismiss,
            additionalAction = additionalAction
        )
    }

    fun showAlert(
        message: String,
        title: String? = null,
        onDismiss: () -> Unit = {},
        additionalAction: Pair<String, () -> Unit>? = null,
        positiveAction: Pair<String, () -> Unit>? = null
    ) {
        if (displayedDialog != null) {
            log.w("Ignoring new dialog request, one is already being displayed")
            return
        }

        val ctx = context.requireContext()
        val builder = AlertDialog.Builder(ctx)
        builder.setTitle(title ?: ctx.getString(R.string.alert_error_header))
        builder.setMessage(message)

        if (positiveAction == null) {
            builder.setPositiveButton(ctx.getString(R.string.universal_action_close)) { dialog, _ ->
                dismiss()
            }
        } else {
            builder.setPositiveButton(positiveAction.first) { dialog, _ ->
                dismiss()
                positiveAction.second()
            }
            builder.setNeutralButton(ctx.getString(R.string.universal_action_close)) { dialog, _ ->
                dismiss()
            }
        }

        additionalAction?.run {
            builder.setNeutralButton(first) { dialog, _ ->
                dismiss()
                second()
            }
        }

        builder.setOnDismissListener {
            dismiss(it)
            onDismiss()
        }

        displayedDialog = builder.showButNotCrash()
    }

    fun dismiss(dialog: DialogInterface? = displayedDialog) {
        displayedDialog?.let {
            // Android calls dismiss listener with a delay. The usual.
            if (it == dialog) {
                it.dismiss()
                displayedDialog = null
            }
        }
    }

    private fun AlertDialog.Builder.showButNotCrash(): AlertDialog? {
        return try { this.show() } catch (ex: Exception) {
            log.e("Could not show dialog, ignoring: ${ex.message}")
            null
        }
    }

}