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

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.navArgs
import model.NetworkType
import model.isDnsOverHttps
import org.blokada.R
import repository.DnsDataSource
import service.AlertDialogService
import ui.AccountViewModel
import ui.NetworksViewModel
import ui.app
import ui.advanced.packs.OptionView
import ui.utils.getColorFromAttr


class NetworksDetailFragment : Fragment() {

    companion object {
        fun newInstance() = NetworksDetailFragment()
    }

    private val alert = AlertDialogService

    private val args: NetworksDetailFragmentArgs by navArgs()

    private lateinit var viewModel: NetworksViewModel
    private lateinit var accountViewModel: AccountViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            viewModel = ViewModelProvider(it.app()).get(NetworksViewModel::class.java)
            accountViewModel = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_networks_detail, container, false)

        val icon: ImageView = root.findViewById(R.id.network_icon)
        val name: TextView = root.findViewById(R.id.network_name)
        val desc: TextView = root.findViewById(R.id.network_desc)
        val info: View = root.findViewById(R.id.network_info)
        val summaryEncryptDns: TextView = root.findViewById(R.id.network_summary_encrypt_dns)
        val summaryUseDns: TextView = root.findViewById(R.id.network_summary_use_dns)
        val summaryUseDnsPlus: TextView = root.findViewById(R.id.network_summary_use_dns_plus)
        val summaryForceLibre: TextView = root.findViewById(R.id.network_summary_force_libre)
        val actionEncrypt: OptionView = root.findViewById(R.id.network_action_encryptdns)
        val actionUseNetworkDns: OptionView = root.findViewById(R.id.network_action_networkdns)
        val actionChangeDns: OptionView = root.findViewById(R.id.network_action_changedns)
        val actionForceLibre: OptionView = root.findViewById(R.id.network_action_forcelibre)

        viewModel.configs.observe(viewLifecycleOwner, {
            viewModel.getConfigForId(args.networkId).let { cfg ->
                val ctx = requireContext()

                name.text = when {
                    cfg.network.name != null -> cfg.network.name
                    cfg.network.type == NetworkType.WIFI -> ctx.getString(R.string.networks_label_any_wifi)
                    else -> ctx.getString(R.string.networks_label_any_mobile)
                }

                when (cfg.network.type) {
                    NetworkType.FALLBACK -> {
                        // Hide unnecessary things for the "All networks" config
                        icon.setImageResource(R.drawable.ic_baseline_wifi_lock_24)
                        name.text = ctx.getString(R.string.networks_label_all_networks)
                        desc.text = ctx.getString(R.string.networks_label_details_default_network)
                        actionUseNetworkDns.visibility = View.GONE
                        actionForceLibre.visibility = View.GONE
                    }
                    NetworkType.WIFI -> {
                        icon.setImageResource(R.drawable.ic_baseline_wifi_24)
                        desc.text = ctx.getString(R.string.networks_label_specific_network_type)
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
                actionForceLibre.active = cfg.forceLibreMode

                val dns = DnsDataSource.byId(cfg.dnsChoice)
                actionChangeDns.active = true
                actionChangeDns.name = ctx.getString(R.string.networks_action_use_dns, dns.label)
                actionChangeDns.icon = if (dns.isDnsOverHttps())
                    ContextCompat.getDrawable(ctx, R.drawable.ic_baseline_lock_24)
                else
                    ContextCompat.getDrawable(ctx, R.drawable.ic_baseline_no_encryption_24)

                actionEncrypt.setOnClickListener {
                    viewModel.actionEncryptDns(cfg.network, !actionEncrypt.active)
                }

                actionUseNetworkDns.setOnClickListener {
                    val wantsToUse = !actionUseNetworkDns.active
                    viewModel.actionUseNetworkDns(cfg.network, wantsToUse)
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

                actionForceLibre.setOnClickListener {
                    val wantsToUse = !actionForceLibre.active
                    viewModel.actionForceLibreMode(cfg.network, wantsToUse)
                }

                // Summary based on selected actions
                summaryEncryptDns.visibility = if (cfg.encryptDns) View.VISIBLE else View.GONE
                summaryUseDnsPlus.visibility = when {
                    !accountViewModel.isActive() -> View.GONE
                    cfg.useNetworkDns && !cfg.useBlockaDnsInPlusMode -> View.VISIBLE
                    cfg.useBlockaDnsInPlusMode -> View.VISIBLE
                    else -> View.GONE
                }
                summaryUseDnsPlus.text = when {
                    cfg.useBlockaDnsInPlusMode -> ctx.getString(R.string.networks_summary_blocka_plus_mode)
                    else -> ctx.getString(R.string.networks_summary_network_dns_and_plus_mode)
                }
                summaryUseDns.text = when {
                    cfg.useNetworkDns -> ctx.getString(R.string.networks_summary_network_dns, dns.label)
                    else -> ctx.getString(R.string.networks_summary_use_dns, dns.label)
                }
                summaryForceLibre.visibility = if (cfg.forceLibreMode) View.VISIBLE else View.GONE
            }
        })

        return root
    }
}
