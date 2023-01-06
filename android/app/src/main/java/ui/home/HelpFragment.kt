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

class HelpFragment : BottomSheetFragment() {

    private lateinit var vm: AccountViewModel

    companion object {
        fun newInstance() = HelpFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_help, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        val kb: View = root.findViewById(R.id.help_kb)
        kb.setOnClickListener {
            val nav = findNavController()
            nav.navigate(R.id.navigation_settings)
            nav.navigate(SettingsFragmentDirections.actionNavigationSettingsToWebFragment(
                Links.kb, getString(R.string.universal_label_help)
            ))
            dismiss()
        }

        vm.account.observe(viewLifecycleOwner, Observer { account ->
            val contact: View = root.findViewById(R.id.help_contact)
            contact.setOnClickListener {
                val nav = findNavController()
                nav.navigate(R.id.navigation_settings)
                nav.navigate(SettingsFragmentDirections.actionNavigationSettingsToWebFragment(
                    Links.support(account.id), getString(R.string.universal_action_contact_us)
                ))
                dismiss()
            }
        })

        return root
    }

}