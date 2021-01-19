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
import service.AlertDialogService
import service.ConnectivityService
import service.NetworkMonitorPermissionService
import ui.NetworksViewModel
import ui.app
import ui.settings.getIntentForAppInfo
import ui.utils.getColor
import ui.utils.getColorFromAttr

class NetworksFragment : Fragment() {

    private val perms = NetworkMonitorPermissionService
    private val dialog = AlertDialogService

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
        val permsText: TextView = root.findViewById(R.id.network_perms_text)
        permsButton.setOnClickListener {
            dialog.showAlert(
                message = getString(R.string.networks_permission_dialog),
                title = getString(R.string.universal_status_confirm),
                positiveAction = getString(R.string.universal_action_continue) to {
                    perms.askPermission()
                }
            )
        }

         val showPermsGrantedInfo = {
            permsText.text = getString(R.string.networks_permission_request_granted)
            permsText.setTextColor(getColor(R.color.green))
            permsButton.setOnClickListener {
                dialog.showAlert(
                    message = getString(R.string.networks_permission_dialog),
                    title = getString(R.string.universal_label_help),
                    positiveAction = getString(R.string.universal_action_revoke) to {
                        val ctx = requireContext()
                        ctx.startActivity(getIntentForAppInfo(ctx))
                    }
                )
            }
        }
        if (perms.hasPermission()) showPermsGrantedInfo()

        perms.onPermissionGranted = {
            showPermsGrantedInfo()
            ConnectivityService.rescan()
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
