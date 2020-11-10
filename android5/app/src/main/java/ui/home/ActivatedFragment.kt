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

package ui.home

import android.content.DialogInterface
import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import org.blokada.R
import ui.ActivationViewModel
import ui.BottomSheetFragment

class ActivatedFragment : BottomSheetFragment() {

    private lateinit var vm: ActivationViewModel

    companion object {
        fun newInstance() = ActivatedFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it).get(ActivationViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_activated, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val proceed: View = root.findViewById(R.id.activated_continue)
        proceed.setOnClickListener {
            dismiss()
            val fragment = LocationFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        return root
    }

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        vm.setInformedUserAboutActivation()
    }

}