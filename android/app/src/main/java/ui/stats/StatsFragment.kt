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

package ui.stats

import android.os.Bundle
import android.view.*
import android.widget.SearchView
import androidx.core.graphics.drawable.DrawableCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.tabs.TabLayout
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.HistoryEntry
import org.blokada.R
import repository.Repos
import service.AlertDialogService
import service.EnvironmentService
import ui.StatsViewModel
import ui.app
import ui.utils.getColorFromAttr
import utils.Links

class StatsFragment : Fragment() {

    private lateinit var vm: StatsViewModel

    private lateinit var searchGroup: ViewGroup
    private lateinit var search: SearchView
    private lateinit var menu: Menu

    private val cloudRepo by lazy { Repos.cloud }

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        setHasOptionsMenu(true)
        activity?.let {
            vm = ViewModelProvider(it.app()).get(StatsViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_stats, container, false)

        searchGroup = root.findViewById(R.id.activity_searchgroup)
        searchGroup.visibility = View.GONE

        val adapter = StatsAdapter(vm, interaction = object : StatsAdapter.Interaction {
            override fun onClick(item: HistoryEntry) {
                val nav = findNavController()
                nav.navigate(StatsFragmentDirections.actionNavigationActivityToActivityDetailFragment(item.name))
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

        when(vm.getSorting()) {
            StatsViewModel.Sorting.TOP -> tabs.selectTab(tabs.getTabAt(1))
            else -> tabs.selectTab(tabs.getTabAt(0))
        }

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {

            override fun onTabReselected(tab: TabLayout.Tab?) {
                vm.refresh()
                recycler.scrollToTop()
            }

            override fun onTabUnselected(tab: TabLayout.Tab?) {}

            override fun onTabSelected(tab: TabLayout.Tab) {
                val sorting = when(tab.position) {
                    0 -> StatsViewModel.Sorting.RECENT
                    else -> StatsViewModel.Sorting.TOP
                }
                vm.sort(sorting)
                recycler.scrollToTop()
            }

        })

        val updateTabsAndFilter = {
            when (vm.getFilter()) {
                StatsViewModel.Filter.ALLOWED -> {
                    tabs.getTabAt(1)?.text = getString(R.string.activity_category_top_allowed)
//                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
                }
                StatsViewModel.Filter.BLOCKED -> {
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
        vm.getSearch()?.run { search.setQuery(this, false) }
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
                if (term.isNotBlank()) {
                    vm.search(term.trim())
                } else {
                    vm.search(null)
                }
                syncMenuIcons()
                return true
            }

        })

        val empty: View = root.findViewById(R.id.activity_empty)

        vm.history.observe(viewLifecycleOwner, Observer {
            if (it.isNotEmpty()) empty.visibility = View.GONE
            adapter.swapData(it)
            updateTabsAndFilter()
            syncMenuIcons()
        })

        lifecycleScope.launch {
            // Let the user see as the stats refresh
            delay(1000)
            vm.refresh()
        }

        val retention: StatsRetentionView = root.findViewById(R.id.activity_retention)
        retention.lifecycleScope = lifecycleScope
        retention.openPolicy = {
            val nav = findNavController()
            nav.navigate(
                StatsFragmentDirections.actionNavigationActivityToWebFragment(
                    Links.privacy, getString(R.string.payment_action_terms_and_privacy)
                )
            )
        }
        retention.setup()

        lifecycleScope.launch {
            cloudRepo.activityRetentionHot
                .collect {
                    retention.visibility = if (it == "24h") View.GONE else View.VISIBLE
                }
        }

        return root
    }

    private fun getDeviceList(): List<String> {
        return (
            listOf(EnvironmentService.getDeviceAlias())
            + (vm.stats.value?.entries?.map { it.device } ?: emptyList())
        ).distinct()
    }

    private fun RecyclerView.scrollToTop() {
        lifecycleScope.launch {
            delay(1000) // Just Android things
            smoothScrollToPosition(0)
        }
    }

    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
        this.menu = menu
        syncMenuIcons()
        inflater.inflate(R.menu.stats_menu, menu)
        super.onCreateOptionsMenu(menu, inflater)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.stats_search -> {
                if (vm.stats.value?.entries?.isEmpty() == true) {
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
                val fragment = StatsFilterFragment.newInstance()
                fragment.show(parentFragmentManager, null)
                true
            }
            R.id.stats_device -> {
                val fragment = StatsDeviceFragment.newInstance()
                fragment.deviceList = getDeviceList()
                fragment.show(parentFragmentManager, null)
                true
            }
            R.id.stats_clear -> {
                AlertDialogService.showAlert(getString(R.string.universal_status_confirm),
                    title = getString(R.string.universal_action_clear),
                    positiveAction = getString(R.string.universal_action_yes) to {
                        vm.clear()
                    })
                true
            }
            else -> false
        }
    }

    private fun syncMenuIcons() {
        if (!this::menu.isInitialized) return

        menu.findItem(R.id.stats_search)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (vm.getSearch() != null) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }

        menu.findItem(R.id.stats_device)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (vm.getDevice() != null) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }

        menu.findItem(R.id.stats_filter)?.icon?.let {
            DrawableCompat.setTint(it, requireContext().getColorFromAttr(
                if (vm.getFilter() != StatsViewModel.Filter.ALL) android.R.attr.colorPrimary
                else android.R.attr.textColor
            ))
        }
    }

}
