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

package ui.advanced.networks

import android.view.LayoutInflater
import android.view.View
import android.view.View.OnClickListener
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.switchmaterial.SwitchMaterial
import model.NetworkDescriptor
import model.NetworkType
import org.blokada.R
import ui.NetworksViewModel
import ui.utils.getColorFromAttr

class NetworksAdapter(
    private val viewModel: NetworksViewModel,
    private val interaction: Interaction? = null
) :
    ListAdapter<NetworkDescriptor, NetworksAdapter.NetworkViewHolder>(NetworkDescriptorDC()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = NetworkViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_network, parent, false), interaction
    )

    override fun onBindViewHolder(holder: NetworkViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<NetworkDescriptor>) {
        submitList(data.toMutableList())
    }

    inner class NetworkViewHolder(
        itemView: View,
        private val interaction: Interaction?
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val icon: ImageView = itemView.findViewById(R.id.network_icon)
        private val name: TextView = itemView.findViewById(R.id.network_name)
        private val config: TextView = itemView.findViewById(R.id.network_config)
        private val active: SwitchMaterial = itemView.findViewById(R.id.network_switch)

        init {
            itemView.setOnClickListener(this)
            active.setOnClickListener {
                if (adapterPosition != RecyclerView.NO_POSITION) {
                    val clicked = getItem(adapterPosition)
                    interaction?.onEnabled(clicked, active.isChecked)
                }
            }
        }

        override fun onClick(v: View?) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            interaction?.onClick(clicked)
        }

        fun bind(item: NetworkDescriptor) = with(itemView) {
            val ctx = itemView.context

            name.text = when {
                item.name != null -> item.name
                item.type == NetworkType.WIFI -> ctx.getString(R.string.networks_label_any_wifi)
                else -> ctx.getString(R.string.networks_label_any_mobile)
            }

            if (item.type == NetworkType.WIFI) {
                icon.setImageResource(R.drawable.ic_baseline_wifi_24)
            } else {
                icon.setImageResource(R.drawable.ic_baseline_signal_cellular_4_bar_24)
            }

            val cfg = viewModel.getConfig(item)
            if (item == viewModel.getActiveNetworkConfig().network) {
                icon.setColorFilter(ctx.getColor(R.color.green))
                config.text = cfg.summarizeLocalised(ctx)
                active.isChecked = true
            } else {
                icon.setColorFilter(ctx.getColorFromAttr(android.R.attr.textColor))
                active.isChecked = cfg.enabled

                config.text = when {
                    !cfg.enabled -> ctx.getString(R.string.networks_label_configuration_inactive)
                    else -> cfg.summarizeLocalised(ctx)
                }
            }
        }

    }

    interface Interaction {
        fun onClick(item: NetworkDescriptor)
        fun onEnabled(item: NetworkDescriptor, enabled: Boolean)
    }

    private class NetworkDescriptorDC : DiffUtil.ItemCallback<NetworkDescriptor>() {
        override fun areItemsTheSame(
            oldItem: NetworkDescriptor,
            newItem: NetworkDescriptor
        ): Boolean {
            return oldItem == newItem
        }

        override fun areContentsTheSame(
            oldItem: NetworkDescriptor,
            newItem: NetworkDescriptor
        ): Boolean {
            return false
        }
    }
}