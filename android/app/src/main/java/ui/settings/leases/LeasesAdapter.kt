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

import androidx.recyclerview.widget.RecyclerView
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.View.OnClickListener
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import model.Lease
import org.blokada.R

class LeasesAdapter(private val interaction: Interaction) :
    ListAdapter<Lease, LeasesAdapter.LeaseViewHolder>(LeaseDC()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = LeaseViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_lease, parent, false), interaction
    )

    override fun onBindViewHolder(holder: LeaseViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<Lease>) {
        submitList(data.toMutableList())
    }

    inner class LeaseViewHolder(
        itemView: View,
        private val interaction: Interaction
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val name: TextView = itemView.findViewById(R.id.lease_name)
        private val deleteButton: View = itemView.findViewById(R.id.lease_delete)
        private val thisDevice: View = itemView.findViewById(R.id.lease_thisdevice)

        init {
            deleteButton.setOnClickListener(this)
        }

        override fun onClick(v: View) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            interaction.onDelete(clicked)
            itemView.alpha = 0.5f
        }

        fun bind(item: Lease) = with(itemView) {
            name.text = item.niceName()
            if (interaction.isThisDevice(item)) {
                thisDevice.visibility = View.VISIBLE
                deleteButton.visibility = View.GONE
            } else {
                thisDevice.visibility = View.GONE
                deleteButton.visibility = View.VISIBLE
            }
        }
    }

    interface Interaction {
        fun onDelete(lease: Lease)
        fun isThisDevice(lease: Lease): Boolean
    }

    private class LeaseDC : DiffUtil.ItemCallback<Lease>() {
        override fun areItemsTheSame(
            oldItem: Lease,
            newItem: Lease
        ): Boolean {
            return oldItem == newItem
        }

        override fun areContentsTheSame(
            oldItem: Lease,
            newItem: Lease
        ): Boolean {
            return oldItem == newItem
        }
    }
}