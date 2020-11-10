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

package ui.advanced.apps

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.SearchView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.tabs.TabLayout
import model.App
import org.blokada.R
import ui.utils.getColorFromAttr

class AppsFragment : Fragment() {

    private lateinit var vm: AppsViewModel

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        activity?.run {
            vm = ViewModelProvider(this).get(AppsViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_apps, container, false)

        val filter: ImageView = root.findViewById(R.id.app_filter)
        filter.setOnClickListener {
            val fragment = AppsFilterFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        val adapter = AppsAdapter(interaction = object : AppsAdapter.Interaction {
            override fun onClick(item: App) {
                vm.switchBypass(item.id)
            }
        })

        val manager = LinearLayoutManager(context)
        val recycler: RecyclerView = root.findViewById(R.id.app_recyclerview)
        recycler.adapter = adapter
        recycler.layoutManager = manager

        val tabs: TabLayout = root.findViewById(R.id.app_tabs)

        // Needed for dynamic translation
        tabs.getTabAt(0)?.text = getString(R.string.apps_label_installed)
        tabs.getTabAt(1)?.text = getString(R.string.apps_label_system)

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {

            override fun onTabReselected(tab: TabLayout.Tab?) {}
            override fun onTabUnselected(tab: TabLayout.Tab?) {}

            override fun onTabSelected(tab: TabLayout.Tab) {
                val group = when(tab.position) {
                    0 -> AppsViewModel.Group.INSTALLED
                    else -> AppsViewModel.Group.SYSTEM
                }
                vm.showGroup(group)
            }

        })

        val updateTabsAndFilter = {
            when (vm.getFilter()) {
                AppsViewModel.Filter.BYPASSED -> {
                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
                }
                AppsViewModel.Filter.NOT_BYPASSED -> {
                    filter.setColorFilter(requireContext().getColorFromAttr(android.R.attr.colorPrimary))
                }
                else -> {
                    filter.setColorFilter(null)
                }
            }
        }

        val search: SearchView = root.findViewById(R.id.app_search)
        search.setOnQueryTextListener(object : SearchView.OnQueryTextListener {

            override fun onQueryTextSubmit(term: String): Boolean {
                return false
            }

            override fun onQueryTextChange(term: String): Boolean {
                if (term.isNotBlank()) vm.search(term.trim())
                else vm.search(null)
                return true
            }

        })

        vm.apps.observe(viewLifecycleOwner, Observer {
            adapter.swapData(it)
            updateTabsAndFilter()
        })

        return root
    }

}
