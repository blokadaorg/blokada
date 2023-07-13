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
import androidx.lifecycle.lifecycleScope
import androidx.preference.EditTextPreference
import androidx.preference.PreferenceFragmentCompat
import binding.AccountBinding
import binding.CommandBinding
import channel.command.CommandName
import kotlinx.coroutines.launch
import org.blokada.R

class SettingsLogoutFragment : PreferenceFragmentCompat() {
    private val account by lazy { AccountBinding }
    private val command by lazy { CommandBinding }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_logout, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        val accountId: EditTextPreference = findPreference("logout_accountid")!!

        account.live.observe(viewLifecycleOwner, Observer { account ->
            accountId.summary = getString(R.string.account_id_status_unchanged)
        })

        accountId.setOnPreferenceChangeListener { _, id ->
            id as String
//            accountId.text = ""
//            accountId.setDefaultValue("")
            accountId.summary = getString(R.string.account_action_restoring, id)
            lifecycleScope.launch {
                command.execute(CommandName.RESTORE, id)
            }
            true
        }
    }

}