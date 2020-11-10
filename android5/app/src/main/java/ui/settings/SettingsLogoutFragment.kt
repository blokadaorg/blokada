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
import androidx.preference.*
import org.blokada.R
import service.tr
import ui.AccountViewModel
import ui.app
import ui.utils.AndroidUtils
import utils.Links

class SettingsLogoutFragment : PreferenceFragmentCompat() {

    private lateinit var vm: AccountViewModel

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_logout, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val accountId: EditTextPreference = findPreference("logout_accountid")!!

        vm.account.observe(viewLifecycleOwner, Observer { account ->
            accountId.summary = getString(R.string.account_id_status_unchanged)
        })

        accountId.setOnPreferenceChangeListener { _, id ->
            id as String
//            accountId.text = ""
//            accountId.setDefaultValue("")
            accountId.summary = getString(R.string.account_action_restoring, id)
            vm.restoreAccount(accountId = id)
            true
        }
    }

}