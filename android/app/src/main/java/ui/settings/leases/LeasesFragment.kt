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

package ui.settings.leases

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import binding.AccountBinding
import binding.PlusKeypairBinding
import binding.PlusLeaseBinding
import channel.pluslease.Lease
import org.blokada.R

class LeasesFragment : Fragment() {
    private val account by lazy { AccountBinding }

    private val plusLease by lazy { PlusLeaseBinding }
    private val plusKeypair by lazy { PlusKeypairBinding }

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_leases, container, false)

        val recycler: RecyclerView = root.findViewById(R.id.recyclerview)
        recycler.layoutManager = LinearLayoutManager(context)

        account.live.observe(viewLifecycleOwner) { account ->
            val adapter = LeasesAdapter(interaction = object : LeasesAdapter.Interaction {
                override fun onDelete(lease: Lease) {
                    plusLease.deleteLease(lease)
                }

                override fun isThisDevice(lease: Lease): Boolean {
                    return plusKeypair.keypair.value?.publicKey == lease.publicKey
                }
            })
            recycler.adapter = adapter

            plusLease.leasesLive.observe(viewLifecycleOwner) {
                adapter.swapData(it)
            }
        }

        return root
    }
}