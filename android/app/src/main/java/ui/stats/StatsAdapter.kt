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

import android.content.Context
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
import model.HistoryEntry
import model.HistoryEntryType
import net.danlew.android.joda.DateUtils
import org.blokada.R
import org.joda.time.DateTime
import ui.StatsViewModel
import java.lang.Integer.min

class StatsAdapter(
    private val viewModel: StatsViewModel,
    private val interaction: Interaction? = null
) :
    ListAdapter<HistoryEntry, StatsAdapter.ActivityViewHolder>(HistoryEntryDC()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = ActivityViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_activity, parent, false), interaction
    )

    override fun onBindViewHolder(holder: ActivityViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<HistoryEntry>) {
        submitList(data.toMutableList())
    }

    inner class ActivityViewHolder(
        itemView: View,
        private val interaction: Interaction?
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val icon: ImageView = itemView.findViewById(R.id.activity_icon)
        private val iconCounter: TextView = itemView.findViewById(R.id.activity_iconcounter)
        private val name: TextView = itemView.findViewById(R.id.activity_name)
        private val time: TextView = itemView.findViewById(R.id.activity_date)
        private val modified: View = itemView.findViewById(R.id.activity_modified)
        private val redline: View = itemView.findViewById(R.id.activity_redline) // For color blind
        private val count: TextView = itemView.findViewById(R.id.activity_count) // blocked x times

        init {
            itemView.setOnClickListener(this)
        }

        override fun onClick(v: View?) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            interaction?.onClick(clicked)
        }

        fun bind(item: HistoryEntry) = with(itemView) {
            when(item.type) {
                HistoryEntryType.passed_allowed -> {
                    icon.setImageResource(R.drawable.ic_shield_off_outline)
                    icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.green))
                    iconCounter.visibility = View.GONE
                    redline.visibility = View.INVISIBLE
                }
                HistoryEntryType.blocked_denied -> {
                    icon.setImageResource(R.drawable.ic_shield_off_outline)
                    icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.red))
                    iconCounter.visibility = View.GONE
                    redline.visibility = View.VISIBLE
                }
                HistoryEntryType.passed -> {
                    icon.setImageResource(R.drawable.ic_shield_outline)
                    icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.green))
                    iconCounter.visibility = View.VISIBLE
                    redline.visibility = View.INVISIBLE
                }
                else -> {
                    icon.setImageResource(R.drawable.ic_shield_outline)
                    icon.setColorFilter(ContextCompat.getColor(itemView.context, R.color.red))
                    iconCounter.visibility = View.VISIBLE
                    redline.visibility = View.VISIBLE
                }
            }

            // Modified state
            val isOnCustomLists = viewModel.isAllowed(item.name) || viewModel.isDenied(item.name)
            val listApplied = item.type in listOf(HistoryEntryType.blocked_denied, HistoryEntryType.passed_allowed)
            if (isOnCustomLists xor listApplied) {
                modified.visibility = View.VISIBLE
                itemView.alpha = 0.5f
            } else {
                modified.visibility = View.GONE
                itemView.alpha = 1.0f
            }

            iconCounter.text = min(99, item.requests).toString()
            name.text = item.name
            time.text = DateUtils.getRelativeTimeSpanString(time.context,
                DateTime(item.time.time), 0
            )
            count.text = "%s %s".format(
                context.getString(when (item.type) {
                    HistoryEntryType.blocked -> R.string.activity_state_blocked
                    HistoryEntryType.blocked_denied -> R.string.activity_state_blocked
                    else -> R.string.activity_state_allowed
                }),

                if (item.requests == 1) context.getString(R.string.activity_happened_one_time)
                else context.getString(R.string.activity_happened_many_times, item.requests.toString())
            )
        }

        private fun getBlockedAllowedString(context: Context, counter: Int, blocked: Boolean): String {
            val base = context.getString(
                if (blocked) R.string.activity_state_blocked
                else R.string.activity_state_allowed
            )
            val times = if (counter == 1) context.getString(R.string.activity_happened_one_time)
                else context.getString(R.string.activity_happened_many_times, counter.toString())
            return "$base $times"
        }
    }

    interface Interaction {
        fun onClick(item: HistoryEntry)
    }

    private class HistoryEntryDC : DiffUtil.ItemCallback<HistoryEntry>() {
        override fun areItemsTheSame(
            oldItem: HistoryEntry,
            newItem: HistoryEntry
        ): Boolean {
            return oldItem.name == newItem.name
        }

        override fun areContentsTheSame(
            oldItem: HistoryEntry,
            newItem: HistoryEntry
        ): Boolean {
            return oldItem == newItem
        }
    }
}