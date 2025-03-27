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
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import binding.PaymentBinding
import com.adapty.ui.AdaptyPaywallView

class AdaptyPaymentFragment : BottomSheetFragment(skipSwipeable = true) {

    private val payment by lazy { PaymentBinding }

    var adaptyView: AdaptyPaywallView? = null

    companion object {
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
            parentFragmentManager.beginTransaction().remove(this).commit()
            return
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return adaptyView!!
    }

    override fun onDestroy() {
        payment.handleScreenClosed()
        super.onDestroy()
    }
}
