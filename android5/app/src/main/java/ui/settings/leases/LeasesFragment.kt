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

package ui.settings.leases

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import model.Lease
import org.blokada.R
import ui.AccountViewModel
import ui.TunnelViewModel
import ui.app

class LeasesFragment : Fragment() {

    private lateinit var vm: LeasesViewModel
    private lateinit var accountVM: AccountViewModel
    private lateinit var tunnelVM: TunnelViewModel

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it).get(LeasesViewModel::class.java)
            accountVM = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
            tunnelVM = ViewModelProvider(it.app()).get(TunnelViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_leases, container, false)

        val recycler: RecyclerView = root.findViewById(R.id.recyclerview)
        recycler.layoutManager = LinearLayoutManager(context)

        accountVM.account.observe(viewLifecycleOwner, Observer { account ->
            val adapter = LeasesAdapter(interaction = object : LeasesAdapter.Interaction {
                override fun onDelete(lease: Lease) {
                    vm.delete(account.id, lease)
                }

                override fun isThisDevice(lease: Lease): Boolean {
                    return tunnelVM.isMe(lease.public_key)
                }
            })
            recycler.adapter = adapter

            vm.leases.observe(viewLifecycleOwner, Observer {
                adapter.swapData(it)
            })

            vm.fetch(account.id)
        })

        return root
    }
}