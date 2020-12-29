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

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.navArgs
import model.NetworkType
import org.blokada.R
import repository.DnsDataSource
import ui.NetworksViewModel
import ui.app
import ui.advanced.packs.OptionView
import ui.utils.getColorFromAttr


class NetworksDetailFragment : Fragment() {

    companion object {
        fun newInstance() = NetworksDetailFragment()
    }

    private val args: NetworksDetailFragmentArgs by navArgs()

    private lateinit var viewModel: NetworksViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            viewModel = ViewModelProvider(it.app()).get(NetworksViewModel::class.java)
        }

        val root =  inflater.inflate(R.layout.fragment_networks_detail, container, false)

        val icon: ImageView = root.findViewById(R.id.network_icon)
        val name: TextView = root.findViewById(R.id.network_name)
        val desc: TextView = root.findViewById(R.id.network_desc)
        val info: View = root.findViewById(R.id.network_info)
        val fullName: TextView = root.findViewById(R.id.network_fullname)
        val type: TextView = root.findViewById(R.id.network_type)
        val actionEncrypt: OptionView = root.findViewById(R.id.network_action_encryptdns)
        val actionUseNetworkDns: OptionView = root.findViewById(R.id.network_action_networkdns)
        val actionChangeDns: OptionView = root.findViewById(R.id.network_action_changedns)

        viewModel.configs.observe(viewLifecycleOwner, {
            viewModel.getConfigForId(args.networkId).let { cfg ->
                val ctx = requireContext()

                name.text = cfg.network.name ?: cfg.network.type.localised(ctx)
                fullName.text = cfg.network.name ?: ctx.getString(R.string.networks_match_any)
                type.text = cfg.network.type.localised(ctx)

                    when (cfg.network.type) {
                    NetworkType.FALLBACK -> {
                        // Hide unnecessary things for the "All networks" config
                        icon.setImageResource(R.drawable.ic_baseline_wifi_lock_24)
                        name.text = ctx.getString(R.string.networks_label_all_networks)
                        desc.text = ctx.getString(R.string.networks_label_details_default_network)
                        info.visibility = View.GONE
                        actionUseNetworkDns.visibility = View.GONE
                    }
                    NetworkType.WIFI -> {
                        icon.setImageResource(R.drawable.ic_baseline_wifi_24)
                    }
                    else -> {
                        icon.setImageResource(R.drawable.ic_baseline_signal_cellular_4_bar_24)
                    }
                }

                // Color the icon if this the currently active config
                val active = viewModel.getActiveNetworkConfig()
                if (active.network == cfg.network) {
                    icon.setColorFilter(ctx.getColor(R.color.green))
                } else {
                    icon.setColorFilter(ctx.getColorFromAttr(android.R.attr.textColor))
                }

                // Actions and interdependencies between them
                actionEncrypt.active = cfg.encryptDns
                actionUseNetworkDns.active = cfg.useNetworkDns

                actionChangeDns.active = true
                actionChangeDns.name = ctx.getString(R.string.networks_action_use_dns,
                                   DnsDataSource.byId(cfg.dnsChoice).label
                                   )

                actionEncrypt.setOnClickListener {
                    viewModel.actionEncryptDns(cfg.network, !actionEncrypt.active)
                }

                actionUseNetworkDns.setOnClickListener {
                    viewModel.actionUseNetworkDns(cfg.network, !actionUseNetworkDns.active)
                }

                actionChangeDns.setOnClickListener {
                    val fragment = DnsChoiceFragment.newInstance()
                    fragment.selectedDns = cfg.dnsChoice
                    fragment.useBlockaDnsInPlusMode = cfg.useBlockaDnsInPlusMode
                    fragment.onDnsSelected = { dns ->
                        viewModel.actionUseDns(cfg.network, dns, fragment.useBlockaDnsInPlusMode)
                    }
                    fragment.show(parentFragmentManager, null)
                }
            }
        })

        return root
    }
}

internal fun NetworkType.localised(ctx: Context) = when (this) {
    NetworkType.WIFI -> ctx.getString(R.string.networks_type_wifi)
    else -> ctx.getString(R.string.networks_type_mobile)
}
