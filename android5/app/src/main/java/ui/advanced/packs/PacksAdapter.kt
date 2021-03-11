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
            "blocklist" -> R.drawable.feature_blocklist
            "spam404" -> R.drawable.feature_spam404
            "hblock" -> R.drawable.feature_hblock
            "danpollock" -> R.drawable.feature_danpollock
            "mvps" -> R.drawable.feature_mvps
            "cpbl" -> R.drawable.feature_cpbl
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