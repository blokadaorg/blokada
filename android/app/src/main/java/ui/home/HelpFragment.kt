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
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import binding.AccountBinding
import binding.CommandBinding
import channel.command.CommandName
import kotlinx.coroutines.launch
import org.blokada.R
import service.Sheet
import ui.BottomSheetFragment
import ui.settings.SettingsFragmentDirections
import utils.Links

class HelpFragment : BottomSheetFragment() {
    override val modal: Sheet = Sheet.Help

    private val account by lazy { AccountBinding }
    private val command by lazy { CommandBinding }

    companion object {
        fun newInstance() = HelpFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
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

        val logs: View = root.findViewById(R.id.help_log)
        logs.setOnClickListener {
            lifecycleScope.launch {
                command.execute(CommandName.SHARELOG)
            }
            dismiss()
        }

        val rate: View = root.findViewById(R.id.help_rate)
        rate.setOnClickListener {
            lifecycleScope.launch {
                command.execute(CommandName.ROUTE, "home/rate")
            }
            dismiss()
        }

        account.live.observe(viewLifecycleOwner) { account ->
            val contact: View = root.findViewById(R.id.help_contact)
            contact.setOnClickListener {
                val nav = findNavController()
                nav.navigate(R.id.navigation_settings)
                nav.navigate(
                    SettingsFragmentDirections.actionNavigationSettingsToWebFragment(
                        Links.support(account.id), getString(R.string.universal_action_contact_us)
                    )
                )
                dismiss()
            }
        }

        return root
    }

}