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

package ui.journal

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import binding.JournalBinding
import channel.journal.JournalFilterType
import org.blokada.R
import ui.BottomSheetFragment

class JournalFilterFragment : BottomSheetFragment() {
    companion object {
        fun newInstance() = JournalFilterFragment()
    }

    private val journal by lazy { JournalBinding }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
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
            journal.filter(JournalFilterType.ALL)
            dismiss()
        }

        val blocked: View = root.findViewById(R.id.activity_filterblocked)
        blocked.setOnClickListener {
            journal.filter(JournalFilterType.BLOCKED)
            dismiss()
        }

        val allowed: View = root.findViewById(R.id.activity_filterallowed)
        allowed.setOnClickListener {
            journal.filter(JournalFilterType.PASSED)
            dismiss()
        }

        return root
    }

}