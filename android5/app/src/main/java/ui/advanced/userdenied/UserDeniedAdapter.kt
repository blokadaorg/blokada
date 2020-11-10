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

package ui.advanced.userdenied

import android.view.LayoutInflater
import android.view.View
import android.view.View.OnClickListener
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import org.blokada.R

class UserDeniedAdapter(
    private val interaction: Interaction? = null
) :
    ListAdapter<String, UserDeniedAdapter.UserDeniedViewHolder>(UserDeniedDC()) {

    var allowed: Boolean = false

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = UserDeniedViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_userdenied, parent, false), interaction
    )

    override fun onBindViewHolder(holder: UserDeniedViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<String>) {
        submitList(data.toMutableList())
    }

    inner class UserDeniedViewHolder(
        itemView: View,
        private val interaction: Interaction?
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val icon: ImageView = itemView.findViewById(R.id.userdenied_icon)
        private val name: TextView = itemView.findViewById(R.id.userdenied_name)
        private val delete: View = itemView.findViewById(R.id.userdenied_delete)

        init {
            delete.setOnClickListener(this)
        }

        override fun onClick(v: View?) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            interaction?.onDelete(clicked)
        }

        fun bind(item: String) = with(itemView) {
            name.text = item
            if (allowed) {
                icon.setImageResource(R.drawable.ic_shield_outline)
                icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.green))
            } else {
                icon.setImageResource(R.drawable.ic_shield_off_outline)
                icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.red))
            }
        }
    }

    interface Interaction {
        fun onDelete(item: String)
    }

    private class UserDeniedDC : DiffUtil.ItemCallback<String>() {
        override fun areItemsTheSame(
            oldItem: String,
            newItem: String
        ): Boolean {
            return oldItem == newItem
        }

        override fun areContentsTheSame(
            oldItem: String,
            newItem: String
        ): Boolean {
            return oldItem == newItem
        }
    }
}