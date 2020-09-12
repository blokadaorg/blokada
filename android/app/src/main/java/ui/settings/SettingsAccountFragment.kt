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

package ui.settings

import android.os.Bundle
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.preference.Preference
import androidx.preference.PreferenceCategory
import androidx.preference.PreferenceFragmentCompat
import org.blokada.R
import service.AlertDialogService
import ui.AccountViewModel
import ui.SettingsViewModel
import ui.app
import ui.utils.AndroidUtils

class SettingsAccountFragment : PreferenceFragmentCompat() {

    private val alert = AlertDialogService
    private lateinit var vm: SettingsViewModel
    private lateinit var accountVM: AccountViewModel

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_account, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        activity?.let {
            vm = ViewModelProvider(it.app()).get(SettingsViewModel::class.java)
            accountVM = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val accountId: Preference = findPreference("account_id")!!
        val accountType: Preference = findPreference("account_subscription_type")!!
        val activeUntil: Preference = findPreference("account_subscription_active")!!

        accountVM.account.observe(viewLifecycleOwner, Observer { account ->
            accountId.setOnPreferenceClickListener {
                alert.showAlert(message = account.id,
                    title = getString(R.string.account_label_id),
                    additionalAction = getString(R.string.universal_action_copy) to {
                        AndroidUtils.copyToClipboard(account.id)
                    })
                true
            }

            accountType.summary = if (account.isActive()) "Plus" else "Libre"
            activeUntil.summary = if (account.isActive())
                account.active_until.toString()
                else getString(R.string.account_active_forever)
        })

        lifecycleScope.launchWhenCreated {
            accountVM.refreshAccount()
        }
    }

}