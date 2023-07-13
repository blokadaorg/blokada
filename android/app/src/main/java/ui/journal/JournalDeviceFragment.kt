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
import android.widget.Button
import android.widget.TextView
import binding.JournalBinding
import org.blokada.R
import ui.BottomSheetFragment

class JournalDeviceFragment : BottomSheetFragment() {
    companion object {
        fun newInstance() = JournalDeviceFragment()
    }

    private val journal by lazy { JournalBinding }

    var deviceList = listOf<String>()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_stats_device, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        journal.filterLive.observe(viewLifecycleOwner) {
            val header: TextView = root.findViewById(R.id.activity_devices_header)
            header.text = getString(R.string.activity_filter_showing_for,
                it.deviceName.ifEmpty { getString(R.string.activity_device_filter_show_all) }
            )
        }

        val container: ViewGroup = root.findViewById(R.id.activity_devices_container)

        val all = inflater.inflate(R.layout.item_button, container, false) as Button
        all.text = requireContext().getString(R.string.activity_device_filter_show_all)
        all.setOnClickListener {
            journal.filterDevice("")
            dismiss()
        }
        container.addView(all)

        deviceList.forEach { device ->
            val button = inflater.inflate(R.layout.item_button, container, false) as Button
            button.text = device
            button.setOnClickListener {
                journal.filterDevice(device)
                dismiss()
            }
            container.addView(button)
        }

        return root
    }

}