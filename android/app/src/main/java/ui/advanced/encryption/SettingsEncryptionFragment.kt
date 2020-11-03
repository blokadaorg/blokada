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

package ui.advanced.encryption

import android.os.Bundle
import androidx.lifecycle.ViewModelProvider
import androidx.preference.*
import model.Dns
import model.DnsId
import model.isDnsOverHttps
import org.blokada.R
import ui.*

class SettingsEncryptionFragment : PreferenceFragmentCompat() {

    private lateinit var vm: SettingsViewModel
    private lateinit var accountVM: AccountViewModel

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_encryption, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        activity?.let {
            vm = ViewModelProvider(it.app()).get(SettingsViewModel::class.java)
            accountVM = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val dns: ListPreference = findPreference("encryption_dns")!!
        dns.setOnPreferenceChangeListener { _, newValue ->
            vm.setSelectedDns(newValue as String)
            true
        }

        val useBlockaDns: SwitchPreference = findPreference("encryption_blockadns")!!
        useBlockaDns.setOnPreferenceChangeListener { _, newValue ->
            vm.setUseBlockaDnsInPlusMode(newValue as Boolean)
            true
        }

        vm.dnsEntries.observe(viewLifecycleOwner, { entries ->
            val useDoh = vm.localConfig.value?.useDnsOverHttps ?: false
            dns.updateDnsList(entries, useDoh)
        })

        vm.localConfig.observe(viewLifecycleOwner, {
            val entries = vm.dnsEntries.value ?: emptyList()
            dns.updateDnsList(entries, it.useDnsOverHttps)

            useBlockaDns.setDefaultValue(it.useBlockaDnsInPlusMode)
            useBlockaDns.isChecked = it.useBlockaDnsInPlusMode

            findPreference<Preference>("encryption_dns_description")?.summary = if (it.useBlockaDnsInPlusMode) {
                getString(R.string.account_encrypt_header_explanation)
            } else {
                getString(R.string.account_encrypt_header_explanation).substringBefore(".") + "." // Hide DoH info
            }
        })

        vm.selectedDns.observe(viewLifecycleOwner, {
            dns.setDefaultValue(it)
            dns.value = it
        })

        accountVM.account.observe(viewLifecycleOwner, {
            useBlockaDns.isEnabled = it.isActive()
            useBlockaDns.isVisible = it.isActive()
        })

    }

    private fun ListPreference.updateDnsList(entries: List<Pair<DnsId, Dns>>, useDoh: Boolean) {
        val filteredEntries = entries
//        val filteredEntries = entries.filter {
//            val dns = it.second
//            when {
//                //useDoh && dns.isDnsOverHttps() -> true
//                useDoh-> true // Show all when DoH enabled, we can fallback to cleartext
//                !useDoh && dns.canUseInCleartext -> true
//                else -> false
//            }
//        }
        this.entryValues = filteredEntries.map { it.first }.toTypedArray()
        this.entries = filteredEntries.map {
            it.second.label +
            if (useDoh && it.second.isDnsOverHttps()) " [DoH]"
            else if (!it.second.canUseInCleartext) " [DoH]"
            else ""
        }.toTypedArray()
    }

}