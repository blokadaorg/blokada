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
import org.blokada.R
import ui.BottomSheetFragment

class ConnIssuesFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = ConnIssuesFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_connissues, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

//        val more: View = root.findViewById(R.id.connissues_more)
//        more.setOnClickListener {
//            dismiss()
//            val nav = findNavController()
//            nav.navigate(
//                HomeFragmentDirections.actionNavigationHomeToWebFragment(
//                Links.connIssues, "TODO"
//            ))
//        }
//
        val ciContinue: View = root.findViewById(R.id.connissues_continue)
        ciContinue.setOnClickListener {
            dismiss()
        }

        return root
    }

}