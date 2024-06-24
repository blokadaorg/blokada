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

package ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import org.blokada.R
import service.Flavor
import ui.BottomSheetFragment

class PaymentFeaturesFragment : BottomSheetFragment(skipCollapsed = false) {
    var cloud = false
    var family = false

    companion object {
        fun newInstance() = PaymentFeaturesFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(
            if (cloud) R.layout.fragment_payment_features_cloud
            else if (family) R.layout.fragment_payment_features_family
            else R.layout.fragment_payment_features
        , container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
            showPaymentFragmentAgain()
        }

        val paymentContinue: View = root.findViewById(R.id.payment_continue)
        paymentContinue.setOnClickListener {
            dismiss()
            showPaymentFragmentAgain()
        }

        return root
    }

    private fun showPaymentFragmentAgain() {
        if (Flavor.isFamily()) {
            val fragment = FamilyPaymentFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        } else {
            val fragment = CloudPaymentFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }
    }

}