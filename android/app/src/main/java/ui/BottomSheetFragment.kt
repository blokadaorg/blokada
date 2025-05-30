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

package ui

import android.app.Dialog
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import binding.StageBinding
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import service.Sheet
import service.SheetService

abstract class BottomSheetFragment(
    val skipCollapsed: Boolean = true,
    val skipSwipeable: Boolean = false
) : BottomSheetDialogFragment() {
    private val stage by lazy { StageBinding }
    private val sheet by lazy { SheetService }

    open val modal: Sheet? = null

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val dialog =
            super.onCreateDialog(savedInstanceState) as BottomSheetDialog
        dialog.setOnShowListener { dialog ->
            val d = dialog as BottomSheetDialog
            val bottomSheet =
                d.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet) as FrameLayout
            val behavior = BottomSheetBehavior.from(bottomSheet)

            if (skipSwipeable) {
                // Disable dragging/swiping to close
                behavior.addBottomSheetCallback(object : BottomSheetBehavior.BottomSheetCallback() {
                    override fun onStateChanged(bottomSheet: View, newState: Int) {
                        if (newState == BottomSheetBehavior.STATE_DRAGGING) {
                            behavior.state = BottomSheetBehavior.STATE_EXPANDED
                        }
                    }

                    override fun onSlide(bottomSheet: View, slideOffset: Float) {}
                })
            }

            if (skipCollapsed) {
                behavior.state = BottomSheetBehavior.STATE_EXPANDED
                behavior.skipCollapsed = skipCollapsed
            }
        }
        dialog.setOnDismissListener {
//            sheet.sheetDismissed()
        }
        modal?.run { stage.sheetShown(this) }
        return dialog
    }

    override fun onDestroy() {
        super.onDestroy()
        sheet.sheetDismissed()
    }

    override fun dismiss() {
        super.dismiss()
    }
}