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