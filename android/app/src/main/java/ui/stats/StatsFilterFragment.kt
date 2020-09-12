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

package ui.stats

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import org.blokada.R
import ui.BottomSheetFragment
import ui.StatsViewModel
import ui.app

class StatsFilterFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = StatsFilterFragment()
    }

    private lateinit var viewModel: StatsViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            viewModel = ViewModelProvider(it.app()).get(StatsViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_stats_filter, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val cancel: View = root.findViewById(R.id.cancel)
        cancel.setOnClickListener {
            dismiss()
        }

        val all: View = root.findViewById(R.id.activity_filterall)
        all.setOnClickListener {
            viewModel.filter(StatsViewModel.Filter.ALL)
            dismiss()
        }

        val blocked: View = root.findViewById(R.id.activity_filterblocked)
        blocked.setOnClickListener {
            viewModel.filter(StatsViewModel.Filter.BLOCKED)
            dismiss()
        }

        val allowed: View = root.findViewById(R.id.activity_filterallowed)
        allowed.setOnClickListener {
            viewModel.filter(StatsViewModel.Filter.ALLOWED)
            dismiss()
        }

        return root
    }

}