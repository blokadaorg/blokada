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

import android.graphics.PorterDuff
import android.graphics.Typeface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.lifecycle.lifecycleScope
import binding.AccountBinding
import binding.PermBinding
import binding.StageBinding
import binding.getType
import channel.stage.StageModal
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import model.AccountType
import org.blokada.R
import repository.Repos
import service.Sheet
import ui.BottomSheetFragment
import ui.utils.getColor
import ui.utils.getColorFromAttr

class OnboardingFragment : BottomSheetFragment() {
    private val stage by lazy { StageBinding }
    private val account by lazy { AccountBinding }
    private val permsRepo by lazy { Repos.perms }
    private val perms by lazy { PermBinding }

    override val modal: Sheet = Sheet.Activated

    companion object {
        fun newInstance() = OnboardingFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val recheckPerms = {
            GlobalScope.launch(Dispatchers.Main) {
                dismiss()
                permsRepo.askForAllMissingPermissions()
                stage.showModal(StageModal.PERMS) // Show this screen again to confirm
            }
        }

        var finishOnboarding: () -> Any = recheckPerms

        val root = inflater.inflate(R.layout.fragment_afteractivated, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val proceed: View = root.findViewById(R.id.activated_continue)
        proceed.setOnClickListener {
            finishOnboarding()
        }

        val subheader: TextView = root.findViewById(R.id.activated_subheader)
        lifecycleScope.launch {
            combine(
                perms.dnsProfileActivated,
                permsRepo.notificationPermsHot,
                perms.vpnProfileActivated
            ) { dns, notif, vpn -> Triple(dns, notif, vpn) }
            .collect {
                val (dns, notif, vpn) = it
                val isCloud = account.account.value.getType() == AccountType.Cloud
                if (dns && notif && (isCloud || vpn)) {
                    subheader.text = getString(R.string.activated_desc_all_ok)
                    finishOnboarding = ::dismiss
                } else {
                    subheader.text = getString(R.string.activated_desc)
                    finishOnboarding = recheckPerms
                }
            }
        }

        val accountLabel: TextView = root.findViewById(R.id.activated_acc_text)
        lifecycleScope.launch(Dispatchers.Main) {
            account.account.collect {
                accountLabel.text = getString(R.string.activated_label_account, it.getType().name)
            }
        }

        val notifIcon: ImageView = root.findViewById(R.id.activated_notif_icon)
        val notifLabel: TextView = root.findViewById(R.id.activated_notif_text)
        val notifGroup: ViewGroup = root.findViewById(R.id.activated_notif_group)
        notifGroup.setOnClickListener { finishOnboarding() }
        lifecycleScope.launch {
            permsRepo.notificationPermsHot
            .collect { granted ->
                if (granted) {
                    notifIcon.setImageResource(R.drawable.ic_baseline_check_24)
                    notifIcon.setColorFilter(getColor(R.color.green), PorterDuff.Mode.MULTIPLY)
                    notifLabel.text = getString(R.string.activated_label_notif_yes)
                    notifLabel.setTypeface(notifLabel.typeface, Typeface.BOLD)
                } else {
                    notifIcon.setImageResource(R.drawable.ic_baseline_close_24)
                    notifIcon.setColorFilter(getColor(R.color.red), PorterDuff.Mode.MULTIPLY)
                    notifLabel.text = getString(R.string.activated_label_notif_no)
                    notifLabel.setTypeface(notifLabel.typeface, Typeface.NORMAL)
                }
            }
        }

        val dnsIcon: ImageView = root.findViewById(R.id.activated_dns_icon)
        val dnsLabel: TextView = root.findViewById(R.id.activated_dns_text)
        val dnsGroup: ViewGroup = root.findViewById(R.id.activated_dns_group)
        dnsGroup.setOnClickListener { finishOnboarding() }
        lifecycleScope.launch {
            perms.dnsProfileActivated
            .collect { granted ->
                if (granted) {
                    dnsIcon.setImageResource(R.drawable.ic_baseline_check_24)
                    dnsIcon.setColorFilter(getColor(R.color.green), PorterDuff.Mode.MULTIPLY)
                    dnsLabel.text = getString(R.string.activated_label_dns_yes)
                    dnsLabel.setTypeface(dnsLabel.typeface, Typeface.BOLD)
                } else {
                    dnsIcon.setImageResource(R.drawable.ic_baseline_close_24)
                    dnsIcon.setColorFilter(getColor(R.color.red), PorterDuff.Mode.MULTIPLY)
                    dnsLabel.text = getString(R.string.activated_label_dns_no)
                    dnsLabel.setTypeface(dnsLabel.typeface, Typeface.NORMAL)
                }
            }
        }

        val vpnIcon: ImageView = root.findViewById(R.id.activated_vpn_icon)
        val vpnLabel: TextView = root.findViewById(R.id.activated_vpn_text)
        val vpnGroup: ViewGroup = root.findViewById(R.id.activated_vpn_group)
        vpnGroup.setOnClickListener { finishOnboarding() }
        lifecycleScope.launch {
            perms.vpnProfileActivated
            .collect { granted ->
                when {
                    account.account.value.getType() != AccountType.Plus -> {
                        vpnGroup.alpha = 0.5f
                        vpnIcon.setImageResource(R.drawable.ic_baseline_close_24)
                        vpnIcon.setColorFilter(
                            requireContext().getColorFromAttr(android.R.attr.textColorSecondary),
                            PorterDuff.Mode.MULTIPLY
                        )
                        vpnLabel.text = getString(R.string.activated_label_vpn_cloud)
                        vpnLabel.setTypeface(vpnLabel.typeface, Typeface.NORMAL)
                    }
                    granted -> {
                        vpnGroup.alpha = 1.0f
                        vpnIcon.setImageResource(R.drawable.ic_baseline_check_24)
                        vpnIcon.setColorFilter(getColor(R.color.green), PorterDuff.Mode.MULTIPLY)
                        vpnLabel.text = getString(R.string.activated_label_vpn_yes)
                        vpnLabel.setTypeface(vpnLabel.typeface, Typeface.BOLD)
                    }
                    else -> {
                        vpnGroup.alpha = 1.0f
                        vpnIcon.setImageResource(R.drawable.ic_baseline_close_24)
                        vpnIcon.setColorFilter(getColor(R.color.red), PorterDuff.Mode.MULTIPLY)
                        vpnLabel.text = getString(R.string.activated_label_vpn_no)
                        vpnLabel.setTypeface(vpnLabel.typeface, Typeface.NORMAL)
                    }
                }
            }
        }

        return root
    }
}