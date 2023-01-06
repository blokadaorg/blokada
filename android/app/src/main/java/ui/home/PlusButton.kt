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

package ui.home

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.Switch
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import ui.utils.getColorFromAttr
import utils.toBlokadaPlusText
import utils.withBoldSections

class PlusButton : FrameLayout {

    var animate: Boolean = false

    var location: String? = null
        set(value) {
            if (field != value) {
                field = value
                refresh()
            }
        }

    var upgrade: Boolean = true
        set(value) {
            if (field != value) {
                field = value
                refresh()
            }
        }

    var plusActive: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                refresh()
                switch.isChecked = value
            }
        }

    var plusEnabled: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                refresh()
            }
        }

    var visible: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                refresh()
            }
        }

    var onNoLocation = {}

    var onClick = { }
    var onActivated = { activated: Boolean -> }

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    private val plusText by lazy { findViewById<TextView>(R.id.home_plustext) }
    private val switch by lazy { findViewById<Switch>(R.id.home_switch) }
    private val plusButtonBg by lazy { findViewById<Button>(R.id.home_plusbuttonbg) }

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Load attributes
        val a = context.obtainStyledAttributes(attrs, R.styleable.PlusButton, defStyle, 0)

        a.recycle()

        // Inflate
        LayoutInflater.from(context).inflate(R.layout.plusbutton, this, true)

        switch.setOnClickListener {
            if (!isEnabled) {
                // Set it back to what it was since the switch should be disabled
                switch.isChecked = !switch.isChecked
                Unit
            } else if (location != null) {
                if (switch.isChecked) {
                    onActivated(true)
                    refreshBackground(true)
                } else {
                    onActivated(false)
                    refreshBackground(false)
                }
            } else {
                if (switch.isChecked) {
                    switch.isChecked = false
                    onNoLocation()
                    refreshBackground(false)
                } else {
                    onActivated(false)
                    refreshBackground(false)
                }
            }
        }

        plusButtonBg.setOnClickListener {
            when {
                !isEnabled -> Unit
                antiDoubleClick -> Unit
                else -> {
                    antiDoubleClick = true

                    onClick()

                    GlobalScope.launch {
                        delay(500)
                        antiDoubleClick = false
                    }
                }
            }
        }

        translationY = 280f
        refresh()
    }

    private var antiDoubleClick = false
        @Synchronized set
        @Synchronized get

    private fun refresh() {
        when {
            upgrade -> {
                plusText.text = context.getString(R.string.universal_action_upgrade).toBlokadaPlusText()
                plusText.textAlignment = View.TEXT_ALIGNMENT_CENTER
                switch.visibility = View.GONE

                if (animate) plusButtonBg.animate().alpha(1.0f)
                else plusButtonBg.alpha = 1.0f
                plusText.setTextColor(ContextCompat.getColor(context, R.color.white))
                refreshBackground(false)
            }
            location != null && plusActive -> {
                plusText.text = String.format(context.getString(R.string.home_plus_button_location), location)
                    .withBoldSections(context.getColorFromAttr(android.R.attr.textColor))
                plusText.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                switch.visibility = View.VISIBLE
                refreshBackground(true)
            }
            !plusActive && plusEnabled -> {
                plusText.text = "BLOKADA+ is paused"
                    .withBoldSections(context.getColorFromAttr(android.R.attr.textColor))
                plusText.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                switch.visibility = View.INVISIBLE
                refreshBackground(true)
            }
            else -> {
                val text = context.getString(R.string.home_plus_button_deactivated).toBlokadaPlusText()
                plusText.text = text
                plusText.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                switch.visibility = View.VISIBLE
                switch.isChecked = false
                refreshBackground(false)
            }
        }

        if (visible) {
            if (animate) animate().translationY(0.0f)
            else translationY = 0.0f
        } else {
            if (animate) animate().translationY(280.0f)
            else translationY = 280.0f
        }
    }

    private fun refreshBackground(transparent: Boolean) {
        if (transparent) {
            if (animate) plusButtonBg.animate().alpha(0.0f)
            else plusButtonBg.alpha = 0.0f
            plusText.setTextColor(context.getColorFromAttr(android.R.attr.textColor))
        } else {
            if (animate) plusButtonBg.animate().alpha(1.0f)
            else plusButtonBg.alpha = 1.0f
            plusText.setTextColor(ContextCompat.getColor(context, R.color.white))
        }
    }
}