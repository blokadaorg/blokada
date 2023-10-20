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
import androidx.preference.PreferenceFragmentCompat
import binding.AccountBinding
import binding.activeUntil
import binding.getType
import binding.isActive
import org.blokada.R
import utils.toBlokadaText
import utils.toSimpleString

class SettingsFragment : Fragment() {
    private val account by lazy { AccountBinding }

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_settings, container, false)

        account.live.observe(viewLifecycleOwner) { account ->
            val active = root.findViewById<TextView>(R.id.settings_active)
            active.text = if (account.isActive()) {
                getString(
                    R.string.account_status_text,
                    account.getType().toString(),
                    account.activeUntil().toSimpleString()
                )
                    .toBlokadaText()
            } else {
                getString(R.string.account_status_text_inactive).toBlokadaText()
            }
        }

        return root
    }

}

class SettingsMainFragment : PreferenceFragmentCompat() {
    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_main, rootKey)
    }
}
