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
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import androidx.navigation.fragment.findNavController
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import org.blokada.R
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app
import ui.settings.SettingsFragmentDirections
import utils.Links

class PaymentFeaturesFragment : BottomSheetFragment(skipCollapsed = false) {

    private lateinit var vm: AccountViewModel

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

        val root = inflater.inflate(R.layout.fragment_payment_features, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
            val fragment = PaymentFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        val paymentContinue: View = root.findViewById(R.id.payment_continue)
        paymentContinue.setOnClickListener {
            dismiss()
            val fragment = PaymentFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        return root
    }

}