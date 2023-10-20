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
import android.view.*
import android.widget.SearchView
import androidx.core.graphics.drawable.DrawableCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import binding.DeviceBinding
import binding.JournalBinding
import binding.StageBinding
import binding.UiJournalEntry
import channel.journal.JournalFilterType
import channel.stage.StageModal
import com.google.android.material.tabs.TabLayout
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import service.EnvironmentService
import ui.utils.getColorFromAttr
import utils.Links

class JournalFragment : Fragment() {
    private val journal by lazy { JournalBinding }
    private val device by lazy { DeviceBinding }
    private val stage by lazy { StageBinding }

    private lateinit var searchGroup: ViewGroup
    private lateinit var search: SearchView
    private lateinit var menu: Menu

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        setHasOptionsMenu(true)
        val root = inflater.inflate(R.layout.fragment_stats, container, false)

        searchGroup = root.findViewById(R.id.activity_searchgroup)
        searchGroup.visibility = View.GONE

        val adapter = JournalAdapter(interaction = object : JournalAdapter.Interaction {
            override fun onClick(item: UiJournalEntry) {
//                val nav = findNavController()
//                nav.navigate(JournalFragmentDirections
//                    .actionNavigationActivityToActivityDetailFragment(item.entry.domainName))
            }
        })

        val manager = LinearLayoutManager(context)
        val recycler: RecyclerView = root.findViewById(R.id.activity_recyclerview)
        recycler.adapter = adapter
        recycler.layoutManager = manager

        val tabs: TabLayout = root.findViewById(R.id.activity_tabs)

        // Needed for dynamic translation
        tabs.getTabAt(0)?.text = getString(R.string.activity_category_recent)
        tabs.getTabAt(1)?.text = getString(R.string.activity_category_top)

        when(journal.filter.value.sortNewestFirst) {
            true -> tabs.selectTab(tabs.getTabAt(0))
            else -> tabs.selectTab(tabs.getTabAt(1))
        }

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabReselected(tab: TabLayout.Tab?) {
                recycler.scrollToTop()
            }

            override fun onTabUnselected(tab: TabLayout.Tab?) {}

            override fun onTabSelected(tab: TabLayout.Tab) {
                val sortingNewest = when(tab.position) {
                    0 -> true
                    else -> false
                }
                journal.sort(sortingNewest)
                recycler.scrollToTop()
            }
        })

        val updateTabsAndFilter = {
            when (journal.filter.value.showOnly) {
                JournalFilterType.PASSED -> {
                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top_allowed)
//                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
                }
                JournalFilterType.BLOCKED -> {
                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top_blocked)
//                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
                }
                else -> {
                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top)
//                    filter.setColorFilter(null)
                }
            }
        }

        search = root.findViewById(R.id.activity_search)
        journal.filter.value.searchQuery.run { search.setQuery(this, false) }
        search.setOnClickListener {
            search.isIconified = false
            search.requestFocus()
        }
        search.setOnCloseListener {
            searchGroup.visibility = View.GONE
            true
        }
        search.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(term: String): Boolean {
                return false
            }

            override fun onQueryTextChange(term: String): Boolean {
                journal.search(term.trim())
                syncMenuIcons()
                return true
            }
        })

        val empty: View = root.findViewById(R.id.activity_empty)

        journal.entriesLive.observe(viewLifecycleOwner) {
            if (it.isNotEmpty()) empty.visibility = View.GONE
            adapter.swapData(it)
            updateTabsAndFilter()
            syncMenuIcons()
        }

        val retention: RetentionView = root.findViewById(R.id.activity_retention)
        retention.lifecycleScope = lifecycleScope
        retention.openPolicy = {
            stage.setRoute(Links.privacy)
        }
        retention.setup()

        device.retentionLive.observe(viewLifecycleOwner) {
            retention.visibility = if (it == "24h") View.GONE else View.VISIBLE
        }

        return root
    }

    private fun getDeviceList(): List<String> {
        return (
            listOf(EnvironmentService.getDeviceAlias()) + (journal.devices.value)
        ).distinct()
    }

    private fun RecyclerView.scrollToTop() {
        lifecycleScope.launch {
            delay(1000) // Just Android things
            smoothScrollToPosition(0)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
        this.menu = menu
        syncMenuIcons()
        inflater.inflate(R.menu.stats_menu, menu)
        super.onCreateOptionsMenu(menu, inflater)
    }

    @Deprecated("Deprecated in Java")
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.stats_search -> {
                if (journal.entries.value.isEmpty()) {
                    // Ignore action when empty
                } else if (searchGroup.visibility == View.GONE) {
                    searchGroup.visibility = View.VISIBLE
                    search.isIconified = false
                    search.requestFocus()
                } else {
                    searchGroup.visibility = View.GONE
                }
                true
            }
            R.id.stats_filter -> {
                val fragment = JournalFilterFragment.newInstance()
                fragment.show(parentFragmentManager, null)
                true
            }
            R.id.stats_device -> {
                val fragment = JournalDeviceFragment.newInstance()
                fragment.deviceList = getDeviceList()
                fragment.show(parentFragmentManager, null)
                true
            }
            R.id.stats_custom -> {
                lifecycleScope.launch {
                    stage.showModal(StageModal.CUSTOM)
                }
                true
            }
            // TODO: journal clear action
//            R.id.stats_clear -> {
//                AlertDialogService.showAlert(getString(R.string.universal_status_confirm),
//                    title = getString(R.string.universal_action_clear),
//                    positiveAction = getString(R.string.universal_action_yes) to {
//                        vm.clear()
//                    })
//                true
//            }
            else -> false
        }
    }

    private fun syncMenuIcons() {
        if (!this::menu.isInitialized) return

        menu.findItem(R.id.stats_search)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (journal.filter.value.searchQuery.isNotBlank()) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }

        menu.findItem(R.id.stats_device)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (journal.filter.value.deviceName.isNotBlank()) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }

        menu.findItem(R.id.stats_filter)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (journal.filter.value.showOnly != JournalFilterType.ALL) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }
    }

}
