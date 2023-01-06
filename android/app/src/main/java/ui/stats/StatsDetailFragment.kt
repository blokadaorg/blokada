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

package ui.stats

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.navArgs
import model.HistoryEntryType
import org.blokada.R
import service.EnvironmentService
import ui.StatsViewModel
import ui.advanced.packs.OptionView
import ui.app
import ui.utils.AndroidUtils


class StatsDetailFragment : Fragment() {

    companion object {
        fun newInstance() = StatsDetailFragment()
    }

    private val args: StatsDetailFragmentArgs by navArgs()

    private lateinit var viewModel: StatsViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            viewModel = ViewModelProvider(it.app()).get(StatsViewModel::class.java)
        }

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

        viewModel.history.observe(viewLifecycleOwner, Observer {
            viewModel.get(args.historyId)?.run {
                when (this.type) {
                    HistoryEntryType.passed_allowed -> {
                        icon.setImageResource(R.drawable.ic_shield_off_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.green))
                        comment.text = when (this.pack) {
                            null -> getString(R.string.activity_request_allowed_no_list)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_allowed_whitelisted)
                            else -> getString(R.string.activity_request_allowed_list, this.pack)
                        }
                    }
                    HistoryEntryType.blocked_denied -> {
                        icon.setImageResource(R.drawable.ic_shield_off_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.red))
                        comment.text = when (this.pack) {
                            null -> getString(R.string.activity_request_blocked)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_blocked_blacklisted)
                            else -> getString(R.string.activity_request_blocked_list, this.pack)
                        }
                    }
                    HistoryEntryType.passed -> {
                        icon.setImageResource(R.drawable.ic_shield_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.green))
                        comment.text = when (this.pack) {
                            null -> getString(R.string.activity_request_allowed_no_list)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_allowed_whitelisted)
                            else -> getString(R.string.activity_request_allowed_list, this.pack)
                        }
                    }
                    else -> {
                        icon.setImageResource(R.drawable.ic_shield_outline)
                        icon.setColorFilter(ContextCompat.getColor(requireContext(), R.color.red))
                        comment.text = when (this.pack) {
                            null -> getString(R.string.activity_request_blocked)
                            EnvironmentService.deviceTag -> getString(R.string.activity_request_blocked_blacklisted)
                            else -> getString(R.string.activity_request_blocked_list, this.pack)
                        }
                    }
                }

                primaryAction.alpha = 1.0f

                when {
                    viewModel.isDenied(this.name) -> {
                        primaryAction.name = getString(R.string.activity_action_added_to_blacklist)
                        primaryAction.active = true
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            viewModel.undeny(this.name)
                        }
                    }
                    viewModel.isAllowed(this.name) -> {
                        primaryAction.name = getString(R.string.activity_action_added_to_whitelist)
                        primaryAction.active = true
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            viewModel.unallow(this.name)
                        }
                    }
                    this.type == HistoryEntryType.passed -> {
                        primaryAction.name = getString(R.string.activity_action_add_to_blacklist)
                        primaryAction.active = false
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            viewModel.deny(this.name)
                        }
                    }
                    else -> {
                        primaryAction.name = getString(R.string.activity_action_add_to_whitelist)
                        primaryAction.active = false
                        primaryAction.setOnClickListener {
                            primaryAction.alpha = 0.5f
                            viewModel.allow(this.name)
                        }
                    }
                }

                counter.text = requests.toString()
                name.text = this.name
                fullName.text = this.name
                time.text = this.time.toString()
                device.text = this.device

                copyAction.setOnClickListener {
                    AndroidUtils.copyToClipboard(this.name)
                }
            }
        })

        return root
    }

}