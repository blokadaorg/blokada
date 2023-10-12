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

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.navigation.fragment.findNavController
import org.blokada.R
import ui.BottomSheetFragment
import utils.Links

class FirstTimeFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = FirstTimeFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_firsttime, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val more: View = root.findViewById(R.id.firsttime_more)
        more.setOnClickListener {
            dismiss()
            val nav = findNavController()
            nav.navigate(
                FlutterHomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.intro, getString(R.string.intro_header)
                )
            )
        }

        val firstTimeContinue: View = root.findViewById(R.id.firsttime_continue)
        firstTimeContinue.setOnClickListener {
            dismiss()
        }

        return root
    }

}