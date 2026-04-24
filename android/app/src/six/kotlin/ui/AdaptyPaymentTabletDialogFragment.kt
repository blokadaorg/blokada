/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2026 Blocka AB. All rights reserved.
 */

package ui

import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import androidx.fragment.app.DialogFragment
import binding.PaymentBinding
import com.adapty.ui.AdaptyPaywallView
import org.blokada.R

/**
 * Uses a centered dialog on wide screens so the paywall keeps a readable
 * width instead of stretching across the entire tablet window.
 */
class AdaptyPaymentTabletDialogFragment : DialogFragment() {

    private val payment by lazy { PaymentBinding }

    var adaptyView: AdaptyPaywallView? = null

    companion object {
        fun newInstance(view: AdaptyPaywallView): AdaptyPaymentTabletDialogFragment {
            val fragment = AdaptyPaymentTabletDialogFragment()
            fragment.adaptyView = view
            return fragment
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (adaptyView == null) {
            payment.logError(
                "AdaptyPaymentTabletDialogFragment: closing",
                Exception("adaptyView is null")
            )
            dismissAllowingStateLoss()
            return
        }
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog =
        Dialog(requireContext(), R.style.Theme_Blokada_Default).apply {
            window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        }

    override fun onStart() {
        super.onStart()

        dialog?.window?.apply {
            setGravity(Gravity.CENTER)
            setLayout(
                requireContext().centeredAdaptyPaywallWidthPx(),
                requireContext().centeredAdaptyPaywallHeightPx()
            )
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = adaptyView ?: return FrameLayout(requireContext())
        return FrameLayout(requireContext()).apply {
            layoutParams =
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            background = context.getDrawable(R.drawable.adapty_payment_dialog_background)
            clipToOutline = true
            outlineProvider = ViewOutlineProvider.BACKGROUND
            addView(
                view,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
        }
    }
}
