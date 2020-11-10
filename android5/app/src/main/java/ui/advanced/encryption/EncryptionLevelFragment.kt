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

import android.content.Context
import android.graphics.drawable.LevelListDrawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import ui.BottomSheetFragment
import ui.TunnelViewModel
import ui.advanced.AdvancedFragmentDirections
import ui.advanced.statusToLevel
import ui.app
import ui.home.PaymentFragment
import utils.toBlokadaPlusText

class EncryptionLevelFragment : BottomSheetFragment(skipCollapsed = false) {

    private lateinit var tunnelVM: TunnelViewModel

    companion object {
        fun newInstance() = EncryptionLevelFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            tunnelVM = ViewModelProvider(it.app()).get(TunnelViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_encryption_level, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val encryptContinue: Button = root.findViewById(R.id.encryption_continue)
        encryptContinue.setOnClickListener {
            dismiss()
        }

        val encryptLevel = root.findViewById<TextView>(R.id.encryption_level)
        val encryptDns = root.findViewById<View>(R.id.encryption_dns)
        val encryptEverything = root.findViewById<View>(R.id.encryption_everything)
        val encryptIcon = root.findViewById<ImageView>(R.id.encryption_icon)

        tunnelVM.tunnelStatus.observe(viewLifecycleOwner, Observer { status ->
            val level = statusToLevel(status)
            val ctx = requireContext()
            encryptLevel.text = ctx.levelToShortText(level)

            encryptDns.alpha = if (level >= 1) 1.0f else 0.3f
            encryptEverything.alpha = if (level == 2) 1.0f else 0.3f

            (encryptIcon.drawable as? LevelListDrawable)?.let {
                it.level = level
            }

            when (level) {
                2 -> {
                    encryptDns.alpha = 1.0f
                    encryptEverything.alpha = 1.0f
                    encryptContinue.text = getString(R.string.universal_action_continue)
                    encryptContinue.setOnClickListener {
                        dismiss()
                    }
                }
                1 -> {
                    encryptDns.alpha = 1.0f
                    encryptEverything.alpha = 0.3f
                    encryptContinue.text = getString(R.string.universal_action_upgrade).toBlokadaPlusText()
                    encryptContinue.setOnClickListener {
                        dismiss()
                        val nav = findNavController()
                        nav.navigate(R.id.navigation_home)
                        val fragment = PaymentFragment.newInstance()
                        fragment.show(parentFragmentManager, null)
                    }
                }
                else -> {
                    encryptDns.alpha = 0.3f
                    encryptEverything.alpha = 0.3f
                    encryptContinue.text = getString(R.string.home_power_action_turn_on)
                    encryptContinue.setOnClickListener {
                        dismiss()
                        val nav = findNavController()
                        nav.navigate(R.id.navigation_home)
                        tunnelVM.turnOn()
                    }
                }
            }
        })

        return root
    }

}

private fun Context.levelToShortText(level: Int): String {
    return when (level) {
        1 -> getString(R.string.account_encrypt_level_medium)
        2 -> getString(R.string.account_encrypt_level_high)
        else -> getString(R.string.account_encrypt_level_low)
    }
}
