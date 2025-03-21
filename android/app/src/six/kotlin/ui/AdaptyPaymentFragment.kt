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

    lateinit var view: AdaptyPaywallView

    companion object {
        fun newInstance(view: AdaptyPaywallView): AdaptyPaymentFragment {
            val fragment = AdaptyPaymentFragment()
            fragment.view = view
            return fragment
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return view
    }

    override fun onDestroy() {
        payment.handleScreenClosed()
        super.onDestroy()
    }
}
