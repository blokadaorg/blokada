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

package ui.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.NavController
import androidx.preference.Preference
import androidx.preference.PreferenceCategory
import androidx.preference.PreferenceFragmentCompat
import model.Account
import model.AccountId
import model.BlokadaException
import org.blokada.R
import service.ContextService
import service.tr
import ui.AccountViewModel
import ui.app
import ui.utils.AndroidUtils
import utils.Links
import utils.toBlokadaPlusText
import utils.toBlokadaText
import utils.toSimpleString

class SettingsFragment : Fragment() {

    private lateinit var vm: AccountViewModel

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_settings, container, false)

        vm.account.observe(viewLifecycleOwner, Observer { account ->
            val active = root.findViewById<TextView>(R.id.settings_active)
            active.text = if (account.isActive()) {
                getString(R.string.account_status_text, getAccountType(account), account.active_until.toSimpleString())
                    .toBlokadaText()
            } else {
                getString(R.string.account_status_text_libre).toBlokadaText()
            }
        })

        return root
    }

    private fun getAccountType(account: Account) = if (account.isActive()) "Plus" else "Libre"
}

class SettingsMainFragment : PreferenceFragmentCompat() {
    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_main, rootKey)
    }
}

object SettingsNavigation {
    fun handle(nav: NavController, key: String, accountId: AccountId?) {
        val path = when (key) {
            "main_account" -> SettingsFragmentDirections.actionNavigationSettingsToNavigationSettingsAccount()
            "main_logout" -> SettingsFragmentDirections.actionNavigationSettingsToSettingsLogoutFragment()
            "main_leases" -> SettingsFragmentDirections.actionNavigationSettingsToLeasesFragment()
            "main_app" -> SettingsFragmentDirections.actionNavigationSettingsToSettingsAppFragment()
            "main_kb" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.kb, getString(R.string.universal_action_help))
            "main_donate" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.donate, getString(R.string.universal_action_donate))
            "main_community" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.community, getString(R.string.universal_action_community))
            "main_support" -> accountId?.let { SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.support(it), getString(R.string.universal_action_contact_us)) }
            "main_about" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.credits, getString(R.string.account_action_about))
            "account_subscription_manage" -> accountId?.let { SettingsAccountFragmentDirections.actionNavigationSettingsAccountToWebFragment(Links.manageSubscriptions(it), getString(R.string.account_action_manage_subscription)) }
            "account_help_why" -> SettingsAccountFragmentDirections.actionNavigationSettingsAccountToWebFragment(Links.whyUpgrade, getString(R.string.account_action_why_upgrade))
            "logout_howtorestore" -> SettingsLogoutFragmentDirections.actionSettingsLogoutFragmentToWebFragment(Links.howToRestore, getString(R.string.account_action_how_to_restore))
            "logout_support" -> accountId?.let { SettingsLogoutFragmentDirections.actionSettingsLogoutFragmentToWebFragment(Links.support(it), getString(R.string.universal_action_contact_us)) }
            else -> null
        }
        path?.let { nav.navigate(it) }
    }

    private fun getString(id: Int) = ContextService.requireContext().getString(id)
}
