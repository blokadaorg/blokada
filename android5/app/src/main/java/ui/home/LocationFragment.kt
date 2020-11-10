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

import android.location.Location
import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import kotlinx.coroutines.delay
import model.Gateway
import org.blokada.R
import ui.BottomSheetFragment
import ui.TunnelViewModel
import ui.app
import ui.utils.getColorFromAttr

class LocationFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = LocationFragment()
    }

    private lateinit var vm: LocationViewModel
    private lateinit var tunnelVM: TunnelViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it).get(LocationViewModel::class.java)
            tunnelVM = ViewModelProvider(it.app()).get(TunnelViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_location, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        val container1: LinearLayout = root.findViewById(R.id.location_container1)
        val container2: LinearLayout = root.findViewById(R.id.location_container2)
        val container3: LinearLayout = root.findViewById(R.id.location_container3)

        vm.locations.observe(viewLifecycleOwner, {
            val spinner: View = root.findViewById(R.id.spinner)
            spinner.visibility = View.GONE

            container1.removeAllViews()
            container2.removeAllViews()
            container3.removeAllViews()

            val groupedLocations = it.map {
                when {
                    it.region.startsWith("europe") -> 2 to it
                    it.region.startsWith("us") || it.region.startsWith("northamerica") -> 1 to it
                    else -> 3 to it
                }
            }

            for(pairs in groupedLocations) {
                val (region, location) = pairs
                when (region) {
                    1 -> addLocationItemView(inflater, container1, location)
                    2 -> addLocationItemView(inflater, container2, location)
                    else -> addLocationItemView(inflater, container3, location)
                }
            }
        })

        vm.refreshLocations()

        return root
    }

    private fun addLocationItemView(inflater: LayoutInflater, container: ViewGroup, location: Gateway) {
        val item = inflater.inflate(R.layout.item_location, container, false)
        val icon: ImageView = item.findViewById(R.id.location_icon)
        val name: TextView = item.findViewById(R.id.location_name)
        val checkmark: ImageView = item.findViewById(R.id.location_checkmark)

        name.text = location.niceName()

        if (tunnelVM.isCurrentlySelectedGateway(location.public_key)) {
            // Nothing to do
        } else {
            icon.setColorFilter(requireContext().getColorFromAttr(android.R.attr.textColorTertiary))
            checkmark.visibility = View.GONE
        }

        item.setOnClickListener {
            tunnelVM.changeGateway(location)
            dismiss()
        }

        container.addView(item)
        container.alpha = 0f
        container.animate().alpha(1f)
    }
}