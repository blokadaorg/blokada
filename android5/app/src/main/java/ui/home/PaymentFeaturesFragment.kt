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
import androidx.lifecycle.ViewModelProvider
import org.blokada.R
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app

class PaymentFeaturesFragment : BottomSheetFragment(skipCollapsed = false) {

    private lateinit var vm: AccountViewModel

    var cloud = false

    companion object {
        fun newInstance() = PaymentFeaturesFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(
            if (cloud) R.layout.fragment_payment_features_cloud
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
        val fragment = if (cloud) CloudPaymentFragment.newInstance()
        else PaymentFragment.newInstance()
        fragment.show(parentFragmentManager, null)
    }

}