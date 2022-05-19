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
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import androidx.lifecycle.LifecycleCoroutineScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import org.blokada.R
import repository.Repos

class StatsRetentionView : FrameLayout {

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    lateinit var lifecycleScope: LifecycleCoroutineScope
    var openPolicy = {}

    private val cloudRepo by lazy { Repos.cloud }

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Inflate
        LayoutInflater.from(context).inflate(R.layout.view_retention, this, true)
    }

    fun setup() {
        val root = this

        val retentionText = root.findViewById<TextView>(R.id.retention_text)
        val retentionContinue = root.findViewById<Button>(R.id.retention_continue)
        val retentionCurrent = root.findViewById<View>(R.id.retention_current)
        val retentionProgress = root.findViewById<View>(R.id.retention_progress)

        val retentionPolicy = root.findViewById<TextView>(R.id.retention_policy)
        retentionPolicy.setOnClickListener {
            openPolicy()
        }

        val switchWorking = { working: Boolean ->
            if (working) {
                retentionContinue.isEnabled = false
                retentionCurrent.visibility = View.GONE
                retentionProgress.visibility = View.VISIBLE
            } else {
                retentionContinue.isEnabled = true
                retentionCurrent.visibility = View.VISIBLE
                retentionProgress.visibility = View.GONE
            }
        }
        switchWorking(false)

        lifecycleScope.launch {
            cloudRepo.activityRetentionHot
            .collect {
                switchWorking(false)
                val enabled = it == "24h"

                if (enabled) {
                    retentionText.text = context.getString(R.string.activity_retention_option_twofourh)
                    retentionContinue.text = context.getString(R.string.home_power_action_turn_off)
                    retentionContinue.setOnClickListener {
                        switchWorking(true)
                        lifecycleScope.launch { cloudRepo.setActivityRetention("") }
                    }
                } else {
                    retentionText.text = context.getString(R.string.activity_retention_option_none)
                    retentionContinue.text = context.getString(R.string.home_power_action_turn_on)
                    retentionContinue.setOnClickListener {
                        switchWorking(true)
                        lifecycleScope.launch { cloudRepo.setActivityRetention("24h") }
                    }
                }
            }
        }
    }

}