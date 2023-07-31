/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.journal.custom

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import androidx.appcompat.widget.SearchView
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import binding.CustomBinding
import com.google.android.material.tabs.TabLayout
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import service.Sheet
import ui.BottomSheetFragment

class UserDeniedFragment : BottomSheetFragment() {
    override val modal: Sheet = Sheet.Custom

    private val custom by lazy { CustomBinding }

    private var allowed: Boolean = true

    private lateinit var searchGroup: ViewGroup

    companion object {
        fun newInstance() = UserDeniedFragment()
    }

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_userdenied, container, false)

        val cancel: View = root.findViewById(R.id.back)
        cancel.setOnClickListener {
            dismiss()
        }

        val adapter = UserDeniedAdapter(interaction = object : UserDeniedAdapter.Interaction {
            override fun onDelete(item: String) {
                custom.delete(item)
            }
        })

        val input: SearchView = root.findViewById(R.id.activity_custom_input)
        val button: Button = root.findViewById(R.id.activity_custom_add)
        button.setOnClickListener {
            if (allowed) custom.allow(input.query.toString())
            else custom.deny(input.query.toString())
            input.setQuery("", false)
            input.clearFocus()
        }

        val manager = LinearLayoutManager(context)
        val recycler: RecyclerView = root.findViewById(R.id.activity_recyclerview)
        recycler.adapter = adapter
        recycler.layoutManager = manager

        val tabs: TabLayout = root.findViewById(R.id.activity_tabs)

        // Needed for dynamic translation
        tabs.getTabAt(0)?.text = getString(R.string.userdenied_tab_allowed)
        tabs.getTabAt(1)?.text = getString(R.string.userdenied_tab_blocked)

        if (allowed) tabs.selectTab(tabs.getTabAt(0))
        else tabs.selectTab(tabs.getTabAt(1))
        adapter.allowed = allowed

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabReselected(tab: TabLayout.Tab?) {}
            override fun onTabUnselected(tab: TabLayout.Tab?) {}

            override fun onTabSelected(tab: TabLayout.Tab) {
                allowed = tab.position == 0

                button.text = getString(if (allowed) R.string.userdenied_action_allow
                    else R.string.userdenied_action_block, tab.text)

                adapter.allowed = allowed
                val data = if (allowed) custom.allowed.value else custom.denied.value
                adapter.swapData(data.sorted())
            }
        })

//        val updateTabsAndFilter = {
//            when (vm.getFilter()) {
//                StatsViewModel.Filter.ALLOWED -> {
//                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top_allowed)
//                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
//                }
//                StatsViewModel.Filter.BLOCKED -> {
//                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top_blocked)
//                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
//                }
//                else -> {
//                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top)
//                    filter.setColorFilter(null)
//                }
//            }
//        }

//        val search: SearchView = root.findViewById(R.id.activity_search)
//        search.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
//
//            override fun onQueryTextSubmit(term: String): Boolean {
//                return false
//            }
//
//            override fun onQueryTextChange(term: String): Boolean {
//                if (term.isNotBlank()) vm.search(term.trim())
//                else vm.search(null)
//                return true
//            }
//
//        })

        custom.deniedLive.observe(viewLifecycleOwner) {
            if (!allowed) {
                adapter.swapData(it.sorted())
                lifecycleScope.launch {
                    delay(400) // Just Android things
                    recycler.scrollToTop()
                }
            }
        }

        custom.allowedLive.observe(viewLifecycleOwner) {
            if (allowed) {
                adapter.swapData(it.sorted())
                lifecycleScope.launch {
                    delay(400) // Just Android things
                    recycler.scrollToTop()
                }
            }
        }

        return root
    }

    private fun RecyclerView.scrollToTop() {
        smoothScrollToPosition(0)
        //scrollToPositionWithOffset(0, 0)
    }

//    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
//        inflater.inflate(R.menu.stats_menu, menu)
//        super.onCreateOptionsMenu(menu, inflater)
//    }
//
//    override fun onOptionsItemSelected(item: MenuItem): Boolean {
//        return when (item.itemId) {
//            R.id.stats_search -> {
//                if (searchGroup.visibility == View.GONE) {
//                    searchGroup.visibility = View.VISIBLE
//                } else {
//                    searchGroup.visibility = View.GONE
//                }
//                true
//            }
//            else -> false
//        }
//    }
}
