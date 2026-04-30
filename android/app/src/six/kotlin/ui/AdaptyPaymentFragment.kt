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

package ui

import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ProgressBar
import binding.PaymentBinding
import com.adapty.ui.AdaptyPaywallView

class AdaptyPaymentFragment : BottomSheetFragment(skipSwipeable = true) {

    private val payment by lazy { PaymentBinding }

    var adaptyView: AdaptyPaywallView? = null
    private var didAttachAdaptyView = false

    companion object {
        private const val PAYWALL_MOUNT_DELAY_MS = 320L
        private const val PAYWALL_FADE_DURATION_MS = 450L

        fun newInstance(view: AdaptyPaywallView): AdaptyPaymentFragment {
            val fragment = AdaptyPaymentFragment()
            fragment.adaptyView = view
            return fragment
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // We noticed in prod a crash when the fragment is created but the view is null
        // This is a workaround to prevent the crash
        // That could probably happen if system was restoring the view from the saved state
        // But we don't care to show this fragment in such scenario, user can re-open
        if (adaptyView == null) {
            payment.logError("AdaptyPaymentFragment: closing", Exception("adaptyView is null"))
            parentFragmentManager.beginTransaction().remove(this).commit()
            return
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = adaptyView ?: return FrameLayout(requireContext())
        return FrameLayout(requireContext()).apply {
            layoutParams =
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            minimumHeight = resources.displayMetrics.heightPixels

            val loader = ProgressBar(context).apply {
                isIndeterminate = true
            }
            addView(
                loader,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER
                )
            )

            postDelayed({
                if (!isAdded || didAttachAdaptyView) return@postDelayed
                didAttachAdaptyView = true
                (view.parent as? ViewGroup)?.removeView(view)
                view.alpha = 0f
                addView(
                    view,
                    0,
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                )
                view.animate().alpha(1f).setDuration(PAYWALL_FADE_DURATION_MS).start()
                loader.animate()
                    .alpha(0f)
                    .setDuration(PAYWALL_FADE_DURATION_MS)
                    .withEndAction { removeView(loader) }
                    .start()
            }, PAYWALL_MOUNT_DELAY_MS)
        }
    }

    override fun onDestroy() {
        payment.handleScreenClosed(false)
        super.onDestroy()
    }
}
