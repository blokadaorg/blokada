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

package ui.advanced.networks

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.appcompat.widget.SwitchCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import model.Dns
import model.DnsId
import model.isDnsOverHttps
import org.blokada.R
import repository.DnsDataSource
import ui.BottomSheetFragment
import ui.advanced.decks.OptionView

class DnsChoiceFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = DnsChoiceFragment()
    }

    var selectedDns: DnsId? = null
    var useBlockaDnsInPlusMode: Boolean = true
    var onDnsSelected = { dns: DnsId -> }

    private lateinit var useBlockaDns: SwitchCompat

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_dnschoice, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.done)
        cancel.setOnClickListener {
            selectedDns?.run {
                onDnsSelected(this)
            }
            dismiss()
        }

        useBlockaDns = root.findViewById(R.id.dnschoice_useblocka)
        useBlockaDns.isChecked = useBlockaDnsInPlusMode
        useBlockaDns.setOnClickListener {
            useBlockaDnsInPlusMode = !useBlockaDnsInPlusMode
            useBlockaDns.isChecked = useBlockaDnsInPlusMode
        }

        val container1: LinearLayout = root.findViewById(R.id.dnschoice_container1)
        val container2: LinearLayout = root.findViewById(R.id.dnschoice_container2)
        val container3: LinearLayout = root.findViewById(R.id.dnschoice_container3)
        val container4: LinearLayout = root.findViewById(R.id.dnschoice_container4)

        lifecycleScope.launchWhenCreated {
            val spinner: View = root.findViewById(R.id.spinner)
            spinner.visibility = View.GONE

            container1.removeAllViews()
            container2.removeAllViews()
            container3.removeAllViews()
            container4.removeAllViews()

            val it = DnsDataSource.getDns().sortedByDescending { it.isDnsOverHttps() }
            val groupedLocations = it.map {
                when {
                    it.region.startsWith("europe") -> 2 to it
                    it.region.startsWith("us") || it.region.startsWith("northamerica") -> 3 to it
                    it.region.startsWith("asia") || it.region.startsWith("other") -> 4 to it
                    else -> 1 to it
                }
            }

            for(pairs in groupedLocations) {
                val (region, dns) = pairs
                when (region) {
                    1 -> addItemView(container1, dns)
                    2 -> addItemView(container2, dns)
                    3 -> addItemView(container3, dns)
                    else -> addItemView(container4, dns)
                }
            }
        }

        return root
    }

    private fun addItemView(container: ViewGroup, dns: Dns) {
        val item = OptionView(requireContext())

        item.name = dns.label
        item.icon = ContextCompat.getDrawable(requireContext(),
            if (dns.isDnsOverHttps()) R.drawable.ic_baseline_lock_24 else R.drawable.ic_baseline_no_encryption_24
        )
        item.active = dns.id == selectedDns

        item.setOnClickListener {
            item.active = true
            onDnsSelected(dns.id)
            dismiss()
        }

        container.addView(item)
        container.alpha = 0f
        container.animate().alpha(1f)
    }

}