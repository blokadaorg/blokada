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

package ui.journal

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.navArgs
import binding.CustomBinding
import binding.DeckBinding
import binding.JournalBinding
import channel.journal.JournalEntryType
import org.blokada.R
import service.EnvironmentService
import ui.advanced.decks.OptionView
import ui.utils.AndroidUtils


class JournalDetailFragment : Fragment() {

    companion object {
        fun newInstance() = JournalDetailFragment()
    }

    private val custom by lazy { CustomBinding }
    private val journal by lazy { JournalBinding }
    private val deck by lazy { DeckBinding }

    private val args: JournalDetailFragmentArgs by navArgs()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {

        val root =  inflater.inflate(R.layout.fragment_stats_detail, container, false)

        val icon: ImageView = root.findViewById(R.id.activity_icon)
        val name: TextView = root.findViewById(R.id.activity_name)
        val comment: TextView = root.findViewById(R.id.activity_comment)
        val fullName: TextView = root.findViewById(R.id.activity_fullname)
        val time: TextView = root.findViewById(R.id.activity_fulltime)
        val counter: TextView = root.findViewById(R.id.activity_occurrences)
        val device: TextView = root.findViewById(R.id.activity_device)
        val primaryAction: OptionView = root.findViewById(R.id.activity_primaryaction)
        val copyAction: OptionView = root.findViewById(R.id.activity_copyaction)

        val refreshView = {
            journal.get(args.historyId)?.run {
                val deckName = resolveDeckName(this.entry.list)
                when (this.entry.type) {
                    JournalEntryType.PASSEDALLOWED -> {
                        icon.setImageResource(R.drawable.ic_shield_off_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.green))
                        comment.text = when (deckName) {
                            null -> getString(R.string.activity_request_allowed_no_list)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_allowed_whitelisted)
                            else -> getString(R.string.activity_request_allowed_list, deckName)
                        }
                    }

                    JournalEntryType.BLOCKEDDENIED -> {
                        icon.setImageResource(R.drawable.ic_shield_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.red))
                        comment.text = when (deckName) {
                            null -> getString(R.string.activity_request_blocked)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_blocked_blacklisted)
                            else -> getString(R.string.activity_request_blocked_list, deckName)
                        }
                    }

                    JournalEntryType.PASSED -> {
                        icon.setImageResource(R.drawable.ic_shield_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.green))
                        comment.text = when (deckName) {
                            null -> getString(R.string.activity_request_allowed_no_list)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_allowed_whitelisted)
                            else -> getString(R.string.activity_request_allowed_list, deckName)
                        }
                    }

                    else -> {
                        icon.setImageResource(R.drawable.ic_shield_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.red))
                        comment.text = when (deckName) {
                            null -> getString(R.string.activity_request_blocked)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_blocked_blacklisted)
                            else -> getString(R.string.activity_request_blocked_list, deckName)
                        }
                    }
                }

                primaryAction.alpha = 1.0f

                when {
                    custom.isDenied(this.entry.domainName) -> {
                        primaryAction.name = getString(R.string.activity_action_added_to_blacklist)
                        primaryAction.active = true
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            custom.delete(this.entry.domainName)
                        }
                    }

                    custom.isAllowed(this.entry.domainName) -> {
                        primaryAction.name = getString(R.string.activity_action_added_to_whitelist)
                        primaryAction.active = true
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            custom.delete(this.entry.domainName)
                        }
                    }

                    this.entry.type == JournalEntryType.PASSED -> {
                        primaryAction.name = getString(R.string.activity_action_add_to_blacklist)
                        primaryAction.active = false
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            custom.deny(this.entry.domainName)
                        }
                    }

                    else -> {
                        primaryAction.name = getString(R.string.activity_action_add_to_whitelist)
                        primaryAction.active = false
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            custom.allow(this.entry.domainName)
                        }
                    }
                }

                counter.text = this.entry.requests.toString()
                name.text = this.entry.domainName
                fullName.text = this.entry.domainName
                time.text = this.time.toString() // TODO: better string
                device.text = this.entry.deviceName

                copyAction.setOnClickListener {
                    AndroidUtils.copyToClipboard(this.entry.domainName)
                }
            }
        }


        journal.entriesLive.observe(viewLifecycleOwner) {
            refreshView()
        }

        custom.allowedLive.observe(viewLifecycleOwner) {
            refreshView()
        }

        custom.deniedLive.observe(viewLifecycleOwner) {
            refreshView()
        }

        return root
    }

    private fun resolveDeckName(list: String?): String? {
        return when (list) {
            null -> null
            EnvironmentService.deviceTag -> list
            else -> deck.getDeckNameForList(list)
        }
    }
}