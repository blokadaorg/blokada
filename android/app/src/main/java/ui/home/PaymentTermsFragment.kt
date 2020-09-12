/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.home

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.lifecycle.Observer
import androidx.navigation.fragment.findNavController
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import org.blokada.R
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app
import utils.Links

class PaymentTermsFragment : BottomSheetFragment() {

    private lateinit var vm: AccountViewModel

    companion object {
        fun newInstance() = PaymentTermsFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_payment_terms, container, false)
        val nav = findNavController()

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        vm.account.observe(viewLifecycleOwner, Observer { account ->
            val contact: View = root.findViewById(R.id.payment_support)
            contact.setOnClickListener {
                nav.navigate(
                    HomeFragmentDirections.actionNavigationHomeToWebFragment(
                        Links.support(account.id), getString(R.string.universal_action_contact_us)
                    )
                )
                dismiss()
            }
        })

        val terms: View = root.findViewById(R.id.payment_terms)
        terms.setOnClickListener {
            nav.navigate(
                HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.terms, getString(R.string.payment_action_terms)
                )
            )
            dismiss()
        }

        val privacy: View = root.findViewById(R.id.payment_privacy)
        privacy.setOnClickListener {
            nav.navigate(
                HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.privacy, getString(R.string.payment_action_policy)
                )
            )
            dismiss()
        }

        return root
    }

}