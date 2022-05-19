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

package ui.home

import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.lifecycle.ViewModelProvider
import org.blokada.R
import ui.ActivationViewModel
import ui.BottomSheetFragment
import ui.app

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
            vm = ViewModelProvider(it.app()).get(ActivationViewModel::class.java)
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