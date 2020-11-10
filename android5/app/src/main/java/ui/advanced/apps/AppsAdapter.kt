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

import android.os.Handler
import androidx.recyclerview.widget.RecyclerView
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.View.OnClickListener
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import model.App
import model.AppId
import org.blokada.R
import repository.AppRepository

class AppsAdapter(
    private val interaction: Interaction? = null
) :
    ListAdapter<App, AppsAdapter.AppViewHolder>(AppDC()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = AppViewHolder(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.item_app, parent, false), interaction
    )

    override fun onBindViewHolder(holder: AppViewHolder, position: Int) =
        holder.bind(getItem(position))

    fun swapData(data: List<App>) {
        submitList(data.toMutableList())
    }

    inner class AppViewHolder(
        itemView: View,
        private val interaction: Interaction?
    ) : RecyclerView.ViewHolder(itemView), OnClickListener {

        private val icon: ImageView = itemView.findViewById(R.id.app_icon)
        private val name: TextView = itemView.findViewById(R.id.app_name)
        private val packageName: TextView = itemView.findViewById(R.id.app_package)
        private val bypassed: View = itemView.findViewById(R.id.app_bypassed)

        init {
            itemView.setOnClickListener(this)
        }

        override fun onClick(v: View?) {
            if (adapterPosition == RecyclerView.NO_POSITION) return
            val clicked = getItem(adapterPosition)
            itemView.alpha = 0.3f
            interaction?.onClick(clicked)
        }

        fun bind(item: App) = with(itemView) {
            itemView.alpha = 1.0f
            name.text = item.name
            packageName.text = item.id
            bypassed.visibility = if (item.isBypassed) View.VISIBLE else View.GONE
            icon.tag = item.id

            val request = loadIcon.obtainMessage()
            request.obj = icon to item.id
            loadIcon.sendMessage(request)
            Unit
        }
    }

    private val repo = AppRepository

    private val loadIcon = Handler {
        val request = it.obj as Pair<ImageView, AppId>
        val view = request.first
        val currentId = view.tag as AppId
        if (currentId == request.second) {
            repo.getAppIcon(currentId)?.let {
                view.setImageDrawable(it)
            }
        }
        true
    }

    interface Interaction {
        fun onClick(item: App)
    }

    private class AppDC : DiffUtil.ItemCallback<App>() {
        override fun areItemsTheSame(
            oldItem: App,
            newItem: App
        ): Boolean {
            return oldItem == newItem
        }

        override fun areContentsTheSame(
            oldItem: App,
            newItem: App
        ): Boolean {
            return oldItem == newItem && oldItem.isBypassed == newItem.isBypassed
        }
    }
}