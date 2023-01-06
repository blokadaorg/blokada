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

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.lifecycle.Observer
import androidx.navigation.fragment.findNavController
import org.blokada.R
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app
import ui.utils.getColorFromAttr
import utils.Links
import utils.withBoldSections

class PaymentFragment : BottomSheetFragment() {

    private lateinit var vm: AccountViewModel

    companion object {
        fun newInstance() = PaymentFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_payment, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val slugline: TextView = root.findViewById(R.id.payment_slugline)
        slugline.text = getString(R.string.payment_title).withBoldSections(
            requireContext().getColorFromAttr(android.R.attr.textColor)
        )

        vm.account.observe(viewLifecycleOwner, { account ->
            val proceed: View = root.findViewById(R.id.payment_continue)
            proceed.setOnClickListener {
                dismiss()
                val nav = findNavController()
                nav.navigate(HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.manageSubscriptions(account.id), getString(R.string.universal_action_upgrade)
                ))
            }

            val restore: View = root.findViewById(R.id.payment_restore)
            restore.setOnClickListener {
                dismiss()
                val nav = findNavController()
                nav.navigate(HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.howToRestore, getString(R.string.payment_action_restore)
                ))
            }
        })

        val terms: View = root.findViewById(R.id.payment_terms)
        terms.setOnClickListener {
            dismiss()
            val fragment = PaymentTermsFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        val seeAllFeatures: View = root.findViewById(R.id.payment_allfeatures)
        seeAllFeatures.setOnClickListener {
            dismiss()
            val fragment = PaymentFeaturesFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        val seeLocations: View = root.findViewById(R.id.payment_locations)
        seeLocations.setOnClickListener {
            dismiss()
            val fragment = LocationFragment.newInstance()
            fragment.clickable = false
            fragment.show(parentFragmentManager, null)
        }

        return root
    }

}