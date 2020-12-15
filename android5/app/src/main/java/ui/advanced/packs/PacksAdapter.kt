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

package ui.advanced.packs

import android.util.Log
import androidx.recyclerview.widget.RecyclerView
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.View.OnClickListener
import android.widget.Switch
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import com.google.android.material.imageview.ShapeableImageView
import model.Pack
import org.blokada.R
import service.tr

class PacksAdapter(private val interaction: Interaction? = null) :
    ListAdapter<Pack, PacksAdapter.PackViewHolder>(PackDC()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = PackViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_pack, parent, false), interaction
    )

    override fun onBindViewHolder(holder: PackViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<Pack>) {
        submitList(data.toMutableList())
    }

    inner class PackViewHolder(
        itemView: View,
        private val interaction: Interaction?
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val thumb: ShapeableImageView = itemView.findViewById(R.id.pack_thumb)
        private val title: TextView = itemView.findViewById(R.id.pack_title)
        private val slugline: TextView = itemView.findViewById(R.id.pack_slugline)
        private val switch: Switch = itemView.findViewById(R.id.pack_switch)

        init {
            itemView.setOnClickListener(this)
            switch.setOnClickListener {
                if (adapterPosition == RecyclerView.NO_POSITION) Unit
                else {
                    val clicked = getItem(adapterPosition)
                    Log.v("packs", "switched")
                    interaction?.onSwitch(clicked, switch.isChecked)
                }
            }
        }

        override fun onClick(v: View?) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            interaction?.onClick(clicked)
        }

        fun bind(item: Pack) = with(itemView) {
            thumb.setImageResource(getThumb(item))
            title.text = item.meta.title
            slugline.text = item.meta.slugline.tr()
            switch.isChecked = item.status.installed
            switch.isEnabled = !item.status.installing
            Unit
        }

        private fun getThumb(pack: Pack) = when(pack.id) {
            "adaway" -> R.drawable.feature_adaway
            "ddgtrackerradar" -> R.drawable.feature_ddgtrackerradar
            "energized" -> R.drawable.feature_energized
            "goodbyeads" -> R.drawable.feature_goodbyeads
            "phishingarmy" -> R.drawable.feature_phishingarmy
            "stevenblack" -> R.drawable.feature_stevenblack
            "blacklist" -> R.drawable.feature_blacklist
            "exodusprivacy" -> R.drawable.feature_exodusprivacy
            "oisd" -> R.drawable.feature_oisd
            "developerdan" -> R.drawable.feature_developerdan
            else -> R.drawable.feature_phishingarmy // TODO placeholder
        }
    }

    interface Interaction {
        fun onClick(pack: Pack)
        fun onSwitch(pack: Pack, on: Boolean)
    }

    private class PackDC : DiffUtil.ItemCallback<Pack>() {
        override fun areItemsTheSame(
            oldItem: Pack,
            newItem: Pack
        ): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(
            oldItem: Pack,
            newItem: Pack
        ): Boolean {
            return oldItem == newItem && oldItem.status == newItem.status
        }
    }
}