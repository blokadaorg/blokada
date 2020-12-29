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

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import org.blokada.R
import ui.utils.getColorFromAttr

class OptionView : FrameLayout {

    private var _name: String? = null
    private var _active: Boolean = false
    private var _icon: Drawable? = null

    var name: String?
        get() = _name
        set(value) {
            _name = value
            refresh()
        }

    var active: Boolean
        get() = _active
        set(value) {
            _active = value
            refresh()
        }

    var icon: Drawable?
        get() = _icon
        set(value) {
            _icon = value
            refresh()
        }

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    private val iconView by lazy { findViewById<ImageView>(R.id.pack_icon) }
    private val nameView by lazy { findViewById<TextView>(R.id.pack_name) }
    private val checkmarkView by lazy { findViewById<ImageView>(R.id.pack_checkmark) }

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Load attributes
        val a = context.obtainStyledAttributes(
                attrs, R.styleable.OptionView, defStyle, 0)

        _name = a.getString(R.styleable.OptionView_name)
        _active = a.getBoolean(R.styleable.OptionView_active, false)

        if (a.hasValue(R.styleable.OptionView_iconRef)) {
            _icon = a.getDrawable(R.styleable.OptionView_iconRef)
            _icon?.callback = this
        }

        a.recycle()

        // Inflate
        LayoutInflater.from(context).inflate(R.layout.item_option, this, true)

        refresh()
    }

    private fun refresh() {
        nameView.text = name

        _icon?.run {
            iconView.setImageDrawable(this)
        }

        if (active) {
            iconView.setColorFilter(context.getColorFromAttr(android.R.attr.colorPrimary))
            checkmarkView.visibility = View.VISIBLE
            nameView.setTypeface(null, Typeface.BOLD)
        } else {
            iconView.setColorFilter(context.getColorFromAttr(android.R.attr.textColorTertiary))
            checkmarkView.visibility = View.GONE
            nameView.setTypeface(null, Typeface.NORMAL)
        }
    }

}