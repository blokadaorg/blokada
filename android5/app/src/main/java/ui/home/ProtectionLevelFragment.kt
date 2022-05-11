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

import android.content.Context
import android.graphics.drawable.LevelListDrawable
import android.os.Bundle
import android.os.Handler
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.lifecycle.ViewModelProvider
import engine.MetricsService
import org.blokada.R
import repository.DnsDataSource
import service.ConnectivityService
import service.EnvironmentService
import ui.BottomSheetFragment
import ui.TunnelViewModel
import ui.advanced.statusToLevel
import ui.app
import java.lang.Integer.max

class ProtectionLevelFragment : BottomSheetFragment(skipCollapsed = false) {

    private lateinit var tunnelVM: TunnelViewModel

    companion object {
        fun newInstance() = ProtectionLevelFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            tunnelVM = ViewModelProvider(it.app()).get(TunnelViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_encryption_level, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val encryptContinue: Button = root.findViewById(R.id.encryption_continue)
        encryptContinue.setOnClickListener {
            dismiss()
        }

        val encryptLevel = root.findViewById<TextView>(R.id.encryption_level)
        val encryptDns = root.findViewById<View>(R.id.encryption_dns)
        val encryptDnsIcon = root.findViewById<ImageView>(R.id.encryption_dns_icon)
        val encryptEverything = root.findViewById<View>(R.id.encryption_everything)
        val encryptEverythingIcon = root.findViewById<ImageView>(R.id.encryption_everything_icon)
        val encryptIcon = root.findViewById<ImageView>(R.id.encryption_icon)
        val detailDns = root.findViewById<TextView>(R.id.home_detail_dns)
        val detailDoh = root.findViewById<TextView>(R.id.home_detail_dns_doh)
        val detailVpn = root.findViewById<TextView>(R.id.home_detail_vpn)

        tunnelVM.tunnelStatus.observe(viewLifecycleOwner) { status ->
            val level = statusToLevel(status)
            val ctx = requireContext()
            encryptLevel.text = ctx.levelToShortText(level)

            encryptDns.alpha = if (level >= 1) 1.0f else 0.3f
            encryptEverything.alpha = if (level == 2) 1.0f else 0.3f

            (encryptIcon.drawable as? LevelListDrawable)?.let {
                it.level = max(0, level)
            }

            detailDns.text = status.dns?.label ?: ctx.getString(R.string.universal_label_none)
            if (DnsDataSource.network.id == status.dns?.id) {
                detailDns.text = "Network DNS (${ConnectivityService.getActiveNetworkDns()})"
            } else if (!EnvironmentService.isLibre()) {
                detailDns.text = "Blokada Cloud"
            }

            when (level) {
                2 -> {
                    encryptDns.alpha = 1.0f
                    encryptEverything.alpha = 1.0f
                    encryptDnsIcon.setImageResource(R.drawable.ic_baseline_check_24)
                    encryptEverythingIcon.setImageResource(R.drawable.ic_baseline_check_24)
                    detailDoh.text = ctx.getString(R.string.universal_action_yes)
                    detailVpn.text = status.gatewayLabel
//                    encryptContinue.text = getString(R.string.universal_action_close)
//                    encryptContinue.setOnClickListener {
//                        dismiss()
//                    }
                }
                1 -> {
                    encryptDns.alpha = 1.0f
                    encryptEverything.alpha = 0.3f
                    encryptDnsIcon.setImageResource(R.drawable.ic_baseline_check_24)
                    encryptEverythingIcon.setImageResource(R.drawable.ic_baseline_close_24)
                    detailDoh.text = ctx.getString(R.string.universal_action_yes)
                    detailVpn.text = ctx.getString(R.string.universal_label_none)
//                    encryptContinue.text = getString(R.string.universal_action_upgrade).toBlokadaPlusText()
//                    encryptContinue.setOnClickListener {
//                        dismiss()
//                        val nav = findNavController()
//                        nav.navigate(R.id.navigation_home)
//                        val fragment = PaymentFragment.newInstance()
//                        fragment.show(parentFragmentManager, null)
//                    }
                }
                else -> {
                    encryptDns.alpha = 0.3f
                    encryptEverything.alpha = 0.3f
                    encryptDnsIcon.setImageResource(R.drawable.ic_baseline_close_24)
                    encryptEverythingIcon.setImageResource(R.drawable.ic_baseline_close_24)
                    detailDoh.text = ctx.getString(R.string.universal_action_no)
                    detailVpn.text = ctx.getString(R.string.universal_label_none)
//                    encryptContinue.text = getString(R.string.home_power_action_turn_on)
//                    encryptContinue.setOnClickListener {
//                        dismiss()
//                        val nav = findNavController()
//                        nav.navigate(R.id.navigation_home)
//                        tunnelVM.turnOn()
//                    }
                }
            }
        }

        detailPing = root.findViewById(R.id.home_detail_ping)
        pingRefresh.sendEmptyMessage(0)

        return root
    }

    private lateinit var detailPing: TextView
    private val pingRefresh = Handler {
        detailPing.text = MetricsService.lastRtt.run { if (this == 9999L) "-" else toString() }
        reschedulePingRefresh()
        true
    }

    private fun reschedulePingRefresh() {
        if (isAdded) pingRefresh.sendEmptyMessageDelayed(0, 3000)
    }

}

private fun Context.levelToShortText(level: Int): String {
    return when (level) {
        1 -> getString(R.string.home_level_medium)
        2 -> getString(R.string.home_level_high)
        else -> getString(R.string.home_level_low)
    }
}
