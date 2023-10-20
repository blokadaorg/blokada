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
import binding.AccountBinding
import binding.StageBinding
import org.blokada.R
import ui.BottomSheetFragment
import utils.Links

class PaymentTermsFragment : BottomSheetFragment() {
    private val account by lazy { AccountBinding }
    private val stage by lazy { StageBinding }

    companion object {
        fun newInstance() = PaymentTermsFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_payment_terms, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        account.live.observe(viewLifecycleOwner) { account ->
            val contact: View = root.findViewById(R.id.payment_support)
            contact.setOnClickListener {
                stage.setRoute(Links.support(account.id))
                dismiss()
            }
        }

        val terms: View = root.findViewById(R.id.payment_terms)
        terms.setOnClickListener {
            stage.setRoute(Links.terms)
            dismiss()
        }

        val privacy: View = root.findViewById(R.id.payment_privacy)
        privacy.setOnClickListener {
            stage.setRoute(Links.privacy)
            dismiss()
        }

        return root
    }

}