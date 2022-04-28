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
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.findNavController
import org.blokada.R
import service.VpnPermissionService
import ui.BottomSheetFragment
import ui.TunnelViewModel
import ui.app
import utils.Links

class AskVpnProfileFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = AskVpnProfileFragment()
    }

    private val vpnPerm = VpnPermissionService
    private lateinit var vm: TunnelViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(TunnelViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_vpnprofile, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val more: View = root.findViewById(R.id.vpnperm_more)
        more.setOnClickListener {
            dismiss()
            val nav = findNavController()
            nav.navigate(
                HomeFragmentDirections.actionNavigationHomeToWebFragment(
                Links.whyVpnPerms, getString(R.string.app_settings_action_vpn_profile)
            ))
        }

        val vpnContinue: View = root.findViewById(R.id.vpnperm_continue)
        vpnContinue.setOnClickListener {
            vpnPerm.askPermission()
        }

        vpnPerm.onPermissionGranted = { granted ->
            if (granted) {
                vm.turnOn()
                dismiss()
            }
        }

        return root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        vpnPerm.onPermissionGranted = {}
    }

}