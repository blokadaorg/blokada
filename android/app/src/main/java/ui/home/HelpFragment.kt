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
import binding.AccountBinding
import binding.CommandBinding
import binding.LinkBinding
import binding.StageBinding
import channel.command.CommandName
import channel.link.LinkId
import channel.stage.StageModal
import kotlinx.coroutines.launch
import org.blokada.R
import service.Sheet
import ui.BottomSheetFragment

class HelpFragment : BottomSheetFragment() {
    override val modal: Sheet = Sheet.Help

    private val account by lazy { AccountBinding }
    private val command by lazy { CommandBinding }
    private val stage by lazy { StageBinding }
    private val link by lazy { LinkBinding }

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
            link.openLink(LinkId.KNOWLEDGEBASE)
            dismiss()
        }

        val logs: View = root.findViewById(R.id.help_log)
        logs.setOnClickListener {
            lifecycleScope.launch {
                command.execute(CommandName.LOG)
            }
            dismiss()
        }

        val rate: View = root.findViewById(R.id.help_rate)
        rate.setOnClickListener {
            lifecycleScope.launch {
                command.execute(CommandName.MODALSHOW, StageModal.RATE.name)
            }
            dismiss()
        }

        account.live.observe(viewLifecycleOwner) { account ->
            val contact: View = root.findViewById(R.id.help_contact)
            contact.setOnClickListener {
                link.openLink(LinkId.SUPPORT)
                dismiss()
            }
        }

        return root
    }

}