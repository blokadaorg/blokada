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
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import binding.AccountBinding
import binding.StageBinding
import binding.activeUntil
import binding.getSource
import binding.getType
import binding.isActive
import channel.account.Account
import channel.stage.StageModal
import kotlinx.coroutines.launch
import model.AccountType
import org.blokada.R
import service.AlertDialogService
import service.BiometricService
import ui.SettingsViewModel
import ui.app
import ui.utils.AndroidUtils

class SettingsAccountFragment : PreferenceFragmentCompat() {
    private val account by lazy { AccountBinding }

    private val alert = AlertDialogService
    private lateinit var vm: SettingsViewModel

    private val biometric by lazy { BiometricService }
    private val stage by lazy { StageBinding }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_account, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        activity?.let {
            vm = ViewModelProvider(it.app()).get(SettingsViewModel::class.java)
        }

        val accountId: Preference = findPreference("account_id")!!
        val accountType: Preference = findPreference("account_subscription_type")!!
        val activeUntil: Preference = findPreference("account_subscription_active")!!

        account.live.observe(viewLifecycleOwner) { account ->
            accountId.setOnPreferenceClickListener {
                handleShowAccountId(account)
                true
            }

            accountType.summary = when (account.getType()) {
                AccountType.Libre -> getString(R.string.account_plan_none)
                else -> account.getType().toString()
            }
            accountType.setOnPreferenceClickListener {
                when {
                    account.getSource() == "google" -> {
                        stage.showModal(StageModal.PAYMENT)
                    }
                    else -> {}
                }
                true
            }

            activeUntil.summary = if (account.isActive())
                account.activeUntil().toString()
            else getString(R.string.account_status_text_inactive)
        }
    }

    // Will use biometric auth if available or skip it otherwise and just show id
    private fun handleShowAccountId(account: Account) {
        lifecycleScope.launch {
            val fragment = this@SettingsAccountFragment
            if (biometric.isBiometricReady(fragment.requireContext()))
                biometric.auth(fragment) // Will throw on bad auth

            alert.showAlert(message = account.id,
                title = getString(R.string.account_label_id),
                additionalAction = getString(R.string.universal_action_copy) to {
                    AndroidUtils.copyToClipboard(account.id)
                })
        }
    }
}