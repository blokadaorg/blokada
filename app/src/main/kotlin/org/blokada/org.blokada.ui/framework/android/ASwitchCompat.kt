package org.blokada.ui.framework.android

import android.content.Context
import android.util.AttributeSet

class ASwitchCompat(
        private val ctx: Context,
        attributeSet: AttributeSet?
) : android.support.v7.widget.SwitchCompat(ctx, attributeSet) {

    private var isInSetChecked = false

    override fun setChecked(checked: Boolean) {
        isInSetChecked = true
        super.setChecked(checked)
        isInSetChecked = false
    }

    override fun isShown(): Boolean {
        if (isInSetChecked) {
            return visibility == android.view.View.VISIBLE
        }
        return super.isShown()
    }
}
