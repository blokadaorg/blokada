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

package ui.advanced.networks

import android.os.Bundle
import android.view.*
import android.widget.ImageView
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.NetworkDescriptor
import org.blokada.R
import service.NetworkMonitorPermissionService
import ui.NetworksViewModel
import ui.app
import ui.utils.getColorFromAttr

class NetworksFragment : Fragment() {

    private val perms = NetworkMonitorPermissionService
    private lateinit var vm: NetworksViewModel

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        setHasOptionsMenu(true)
        activity?.let {
            vm = ViewModelProvider(it.app()).get(NetworksViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_networks, container, false)

        val permsButton: View = root.findViewById(R.id.network_perms)
        permsButton.visibility = if (perms.hasPermission()) View.GONE else View.VISIBLE
        permsButton.setOnClickListener {
            perms.askPermission()
        }

        perms.onPermissionGranted = {
            permsButton.visibility = View.GONE
        }

        val adapter = NetworksAdapter(vm, interaction = object : NetworksAdapter.Interaction {
            override fun onClick(item: NetworkDescriptor) {
                val nav = findNavController()
                nav.navigate(NetworksFragmentDirections.actionSettingsNetworksFragmentToNetworksDetailFragment(item.id()))
            }

            override fun onEnabled(item: NetworkDescriptor, enabled: Boolean) {
                vm.actionEnable(item, enabled)
            }
        })

        val manager = LinearLayoutManager(context)
        val recycler: RecyclerView = root.findViewById(R.id.network_recyclerview)
        recycler.adapter = adapter
        recycler.layoutManager = manager

        vm.configs.observe(viewLifecycleOwner, {
            adapter.swapData(it.filter { !it.network.isFallback() }.map { it.network })
        })

        // Configure the top "All networks" panel
        root.findViewById<View>(R.id.network_all).setOnClickListener {
            val nav = findNavController()
            nav.navigate(NetworksFragmentDirections.actionSettingsNetworksFragmentToNetworksDetailFragment(
                NetworkDescriptor.fallback().id()
            ))
        }
        root.findViewById<TextView>(R.id.network_config).text = requireContext().getString(R.string.networks_action_network_specific)
        root.findViewById<View>(R.id.network_switch).visibility = View.GONE
        root.findViewById<View>(R.id.network_divider).visibility = View.GONE

        vm.activeConfig.observe(viewLifecycleOwner, {
            adapter.notifyDataSetChanged()
            root.findViewById<ImageView>(R.id.network_icon).setColorFilter(
                if (it.network.isFallback()) {
                    requireContext().getColor(R.color.green)
                } else requireContext().getColorFromAttr(android.R.attr.textColor)
            )
        })

        return root
    }

    private fun RecyclerView.scrollToTop() {
        lifecycleScope.launch {
            delay(1000) // Just Android things
            smoothScrollToPosition(0)
        }
    }

}
