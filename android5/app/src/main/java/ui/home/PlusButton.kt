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

package ui.home

import android.content.Context
import android.graphics.Canvas
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.text.SpannableString
import android.text.style.TextAppearanceSpan
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.*
import androidx.core.content.ContextCompat
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

    var checked: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                refresh()
                switch.isChecked = value
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
            if (!isEnabled) Unit
            else onClick()
        }

        translationY = 280f
        refresh()
    }

    private fun refresh() {
        if (upgrade) {
            plusText.text = context.getString(R.string.universal_action_upgrade).toBlokadaPlusText()
            plusText.textAlignment = View.TEXT_ALIGNMENT_CENTER
            switch.visibility = View.GONE

            if (animate) plusButtonBg.animate().alpha(1.0f)
            else plusButtonBg.alpha = 1.0f
            plusText.setTextColor(ContextCompat.getColor(context, R.color.white))
        } else if (location != null && checked) {
            plusText.text = String.format(context.getString(R.string.home_plus_button_location), location)
                .withBoldSections(context.getColorFromAttr(android.R.attr.textColor))
            plusText.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
            switch.visibility = View.VISIBLE
            refreshBackground(checked)
        } else {
            val text = context.getString(R.string.home_plus_button_deactivated).toBlokadaPlusText()
            plusText.text = text
            plusText.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
            switch.visibility = View.VISIBLE
            switch.isChecked = false
        }

        if (visible) {
            if (animate) animate().translationY(0.0f)
            else translationY = 0.0f
        } else {
            if (animate) animate().translationY(280.0f)
            else translationY = 280.0f
        }
    }

    private fun refreshBackground(checked: Boolean) {
        if (checked) {
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