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

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.NavController
import androidx.preference.PreferenceFragmentCompat
import model.Account
import model.AccountType
import model.toAccountType
import org.blokada.R
import service.ContextService
import service.EnvironmentService
import ui.AccountViewModel
import ui.app
import utils.Links
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
                getString(R.string.account_status_text, account.getType().toString(), account.active_until.toSimpleString())
                    .toBlokadaText()
            } else {
                getString(R.string.account_status_text_inactive).toBlokadaText()
            }
        })

        return root
    }

}

class SettingsMainFragment : PreferenceFragmentCompat() {
    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_main, rootKey)
    }
}

object SettingsNavigation {
    fun handle(activity: Activity, nav: NavController, key: String, account: Account?) {
        val path = when (key) {
            "main_account" -> SettingsFragmentDirections.actionNavigationSettingsToNavigationSettingsAccount()
            "main_logout" -> SettingsFragmentDirections.actionNavigationSettingsToSettingsLogoutFragment()
            "main_leases" -> SettingsFragmentDirections.actionNavigationSettingsToLeasesFragment()
            "main_retention" -> SettingsFragmentDirections.actionNavigationSettingsToRetentionFragment()
            "main_app" -> SettingsFragmentDirections.actionNavigationSettingsToSettingsAppFragment()
            "main_kb" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.kb, getString(R.string.universal_action_help))
            "main_donate" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.donate, getString(R.string.universal_action_donate))
            "main_community" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.community, getString(R.string.universal_action_community))
            "main_support" -> account?.id?.let { SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.support(it), getString(R.string.universal_action_contact_us)) }
            "main_about" -> SettingsFragmentDirections.actionNavigationSettingsToWebFragment(Links.credits, getString(R.string.account_action_about))
            "account_subscription_manage" -> {
                if (EnvironmentService.isLibre())
                    account?.id?.let { SettingsAccountFragmentDirections.actionNavigationSettingsAccountToWebFragment(Links.manageSubscriptions(it), getString(R.string.account_action_manage_subscription)) }
                else null
            }
            "account_help_why" -> SettingsAccountFragmentDirections.actionNavigationSettingsAccountToWebFragment(Links.whyUpgrade, getString(R.string.account_action_why_upgrade))
            "logout_howtorestore" -> SettingsLogoutFragmentDirections.actionSettingsLogoutFragmentToWebFragment(Links.howToRestore, getString(R.string.account_action_how_to_restore))
            "logout_support" -> account?.id?.let { SettingsLogoutFragmentDirections.actionSettingsLogoutFragmentToWebFragment(Links.support(it), getString(R.string.universal_action_contact_us)) }
            else -> null
        }

        when {
            path != null -> nav.navigate(path)
            key == "account_subscription_manage" && !EnvironmentService.isLibre()
                    && account?.type.toAccountType() != AccountType.Libre -> {
                val intent = Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/account/subscriptions"))
                activity.startActivity(intent)
            }
        }
    }

    private fun getString(id: Int) = ContextService.requireContext().getString(id)
}
