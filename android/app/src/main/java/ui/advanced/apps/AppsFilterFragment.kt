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

package ui.advanced.apps

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import org.blokada.R
import ui.BottomSheetFragment

class AppsFilterFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = AppsFilterFragment()
    }

    private lateinit var viewModel: AppsViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.run {
            viewModel = ViewModelProvider(this).get(AppsViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_apps_filter, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        val all: View = root.findViewById(R.id.app_filterall)
        all.setOnClickListener {
            viewModel.filter(AppsViewModel.Filter.ALL)
            dismiss()
        }

        val blocked: View = root.findViewById(R.id.app_filterbypassed)
        blocked.setOnClickListener {
            viewModel.filter(AppsViewModel.Filter.BYPASSED)
            dismiss()
        }

        val allowed: View = root.findViewById(R.id.app_filternotbypassed)
        allowed.setOnClickListener {
            viewModel.filter(AppsViewModel.Filter.NOT_BYPASSED)
            dismiss()
        }

        val toggle: View = root.findViewById(R.id.app_togglesystem)
        toggle.setOnClickListener {
            viewModel.switchBypassForAllSystemApps()
            dismiss()
        }

        return root
    }

}