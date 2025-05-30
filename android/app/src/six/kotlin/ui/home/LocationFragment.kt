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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import binding.PlusBinding
import model.LegacyGateway
import org.blokada.R
import service.Sheet
import ui.BottomSheetFragment
import utils.getColorFromAttr
import utils.Logger

class LocationFragment : BottomSheetFragment() {

    override val modal: Sheet = Sheet.Location

    companion object {
        fun newInstance() = LocationFragment()
    }

    var clickable = true
    var cloud = false

    private val plus by lazy { PlusBinding }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_location, container, false)

        val goBack = {
            dismiss()
        }

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener { goBack() }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener { goBack() }

        if (!clickable) {
            val header: TextView = root.findViewById(R.id.location_header)
            header.setText(R.string.payment_action_see_locations)
        }

        val container1: LinearLayout = root.findViewById(R.id.location_container1)
        val container2: LinearLayout = root.findViewById(R.id.location_container2)
        val container3: LinearLayout = root.findViewById(R.id.location_container3)
        val container4: LinearLayout = root.findViewById(R.id.location_container4)

        plus.gatewaysLive.observe(viewLifecycleOwner) { it ->
            val spinner: View = root.findViewById(R.id.spinner)
            spinner.visibility = View.GONE

            container1.removeAllViews()
            container2.removeAllViews()
            container3.removeAllViews()
            container4.removeAllViews()

            val groupedLocations = it.map {
                when {
                    it.region.startsWith("europe") -> 2 to it
                    it.region.startsWith("australia") -> 4 to it
                    it.region.startsWith("us") || it.region.startsWith("northamerica") -> 1 to it
                    else -> 3 to it
                }
            }

            for (pairs in groupedLocations) {
                val (region, location) = pairs
                when (region) {
                    1 -> addLocationItemView(inflater, container1, location)
                    2 -> addLocationItemView(inflater, container2, location)
                    3 -> addLocationItemView(inflater, container3, location)
                    else -> addLocationItemView(inflater, container4, location)
                }
            }
        }

        return root
    }

    private fun addLocationItemView(
        inflater: LayoutInflater,
        container: ViewGroup,
        location: LegacyGateway
    ) {
        val item = inflater.inflate(R.layout.item_location, container, false)
        val icon: ImageView = item.findViewById(R.id.location_icon)
        val name: TextView = item.findViewById(R.id.location_name)
        val checkmark: ImageView = item.findViewById(R.id.location_checkmark)

        name.text = location.niceName()
        icon.setImageResource(getFlag(location))

        if (clickable && plus.selected.value == location.publicKey) {
            name.setTextColor(requireContext().getColorFromAttr(android.R.attr.colorAccent))
        } else {
            checkmark.visibility = View.GONE
        }

        if (clickable) {
            item.setOnClickListener {
                plus.newPlus(location.publicKey)
                dismiss()
            }
        }

        container.addView(item)
        container.alpha = 0f
        container.animate().alpha(1f)
    }

    private fun getFlag(location: LegacyGateway): Int {
        return when (location.country) {
            "SE" -> R.drawable.flag_se
            "GB" -> R.drawable.flag_gb
            "CA" -> R.drawable.flag_ca
            "NL" -> R.drawable.flag_nl
            "US" -> R.drawable.flag_us
            "JP" -> R.drawable.flag_jp
            "AE" -> R.drawable.flag_ae
            "FR" -> R.drawable.flag_fr
            "DE" -> R.drawable.flag_de
            "CH" -> R.drawable.flag_ch
            "AU" -> R.drawable.flag_au
            "SG" -> R.drawable.flag_sg
            "IT" -> R.drawable.flag_it
            "ES" -> R.drawable.flag_es
            "BG" -> R.drawable.flag_bg
            else -> {
                Logger.w("Location", "No flag asset for: ${location.country}")
                R.drawable.flag_un
            }
        }
    }
}