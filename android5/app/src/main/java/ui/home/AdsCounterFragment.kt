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

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import org.blokada.R
import repository.Repos
import ui.BottomSheetFragment

class AdsCounterFragment : BottomSheetFragment(skipCollapsed = false) {

    private val statsRepo by lazy { Repos.stats }

    companion object {
        fun newInstance() = AdsCounterFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_adscounter, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        lifecycleScope.launch {
            statsRepo.statsHot.collect {
                val counterString = getCounterString(it.getCounter())

                val share: View = root.findViewById(R.id.adscounter_share)
                share.setOnClickListener {
                    dismiss()
                    shareMessage(counterString)
                }

                val counter: TextView = root.findViewById(R.id.adscounter_counter)
                counter.text = counterString
                counter.setOnClickListener {
                    dismiss()
                    shareMessage(counterString)
                }
            }
        }

        return root
    }

    private fun getCounterString(counter: Long): String {
        return when {
            counter >= 1_000_000 -> "%.1fM".format(counter / 1_000_000.0)
            counter >= 1_000 -> "%.1fK".format(counter / 1_000.0)
            else -> counter.toString()
        }
    }

    private fun shareMessage(counterString: String) {
        val sendIntent: Intent = Intent().apply {
            action = Intent.ACTION_SEND
            putExtra(Intent.EXTRA_TEXT, getString(R.string.main_share_message, counterString))
            type = "text/plain"
        }

        val shareIntent = Intent.createChooser(sendIntent, null)
        startActivity(shareIntent)
    }

}