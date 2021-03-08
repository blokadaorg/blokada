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

package ui.advanced.packs

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.tabs.TabLayout
import model.Pack
import org.blokada.R
import ui.app

class PacksFragment : Fragment() {

    private lateinit var vm: PacksViewModel

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(PacksViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_packs, container, false)
        val recycler: RecyclerView = root.findViewById(R.id.pack_recyclerview)
        val tabs: TabLayout = root.findViewById(R.id.pack_tabs)

        val adapter = PacksAdapter(interaction = object : PacksAdapter.Interaction {

            override fun onClick(pack: Pack) {
                val nav = findNavController()
                nav.navigate(PacksFragmentDirections.actionNavigationPacksToPackDetailFragment(pack.id))
            }

            override fun onSwitch(pack: Pack, on: Boolean) {
                if (on) {
                    vm.install(pack)
                } else {
                    vm.uninstall(pack)
                }
            }

        })

        recycler.adapter = adapter
        recycler.layoutManager = LinearLayoutManager(context)

        vm.packs.observe(viewLifecycleOwner, Observer {
            adapter.swapData(it)
        })

        // Needed for dynamic translation
        tabs.getTabAt(0)?.text = getString(R.string.pack_category_highlights)
        tabs.getTabAt(1)?.text = getString(R.string.pack_category_active)
        tabs.getTabAt(2)?.text = getString(R.string.pack_category_all)

        when(vm.getFilter()) {
            PacksViewModel.Filter.ACTIVE -> tabs.selectTab(tabs.getTabAt(1))
            PacksViewModel.Filter.ALL -> tabs.selectTab(tabs.getTabAt(2))
            else -> tabs.selectTab(tabs.getTabAt(0))
        }

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {

            override fun onTabReselected(tab: TabLayout.Tab?) {}
            override fun onTabUnselected(tab: TabLayout.Tab?) {}

            override fun onTabSelected(tab: TabLayout.Tab) {
                val filtering = when(tab.position) {
                    0 -> PacksViewModel.Filter.HIGHLIGHTS
                    1 -> PacksViewModel.Filter.ACTIVE
                    else -> PacksViewModel.Filter.ALL
                }
                vm.filter(filtering)
            }

        })

        return root
    }
}