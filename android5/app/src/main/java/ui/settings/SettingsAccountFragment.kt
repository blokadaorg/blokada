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