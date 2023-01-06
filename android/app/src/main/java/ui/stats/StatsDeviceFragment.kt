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
import android.widget.Button
import android.widget.TextView
import androidx.lifecycle.ViewModelProvider
import org.blokada.R
import ui.BottomSheetFragment
import ui.StatsViewModel
import ui.app

class StatsDeviceFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = StatsDeviceFragment()
    }

    private lateinit var viewModel: StatsViewModel

    var deviceList = listOf<String>()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            viewModel = ViewModelProvider(it.app()).get(StatsViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_stats_device, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        val header: TextView = root.findViewById(R.id.activity_devices_header)
        header.text = getString(R.string.activity_filter_showing_for,
            viewModel.getDevice() ?: getString(R.string.activity_device_filter_show_all)
        )

        val container: ViewGroup = root.findViewById(R.id.activity_devices_container)

        val all = inflater.inflate(R.layout.item_button, container, false) as Button
        all.text = requireContext().getString(R.string.activity_device_filter_show_all)
        all.setOnClickListener {
            viewModel.device(null)
            dismiss()
        }
        container.addView(all)

        deviceList.forEach { device ->
            val button = inflater.inflate(R.layout.item_button, container, false) as Button
            button.text = device
            button.setOnClickListener {
                viewModel.device(device)
                dismiss()
            }
            container.addView(button)
        }

        return root
    }

}