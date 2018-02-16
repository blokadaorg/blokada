package org.blokada.ui.app.android

import android.widget.LinearLayout
import android.widget.TextView
import android.content.Context
import android.util.AttributeSet
import android.view.View
import org.blokada.R
import org.blokada.ui.framework.android.ASwitchCompat

class AWelcomeView(
        val ctx: Context,
        attributeSet: AttributeSet
) : LinearLayout(ctx, attributeSet) {

    enum class Mode(val msg: Int, val on: Int?, val off: Int?) {
        WELCOME(R.string.main_welcome, R.string.main_advanced_on, R.string.main_advanced_off),
        CLEANUP(R.string.main_welcome_cleanup, null, null),
        MIGRATE_21(R.string.main_welcome_migrate, R.string.main_migrate_slim, R.string.main_migrate_prod),
        MIGRATE(R.string.main_welcome_migrate, null, null),
        OBSOLETE(R.string.main_welcome_obsolete, null, null),
        UPDATED(R.string.main_welcome_updated, R.string.main_updated_donate, R.string.main_updated_other)
    }

    var mode = Mode.WELCOME
        set(value) {
            if (field != value) {
                field = value
                update()
            }
        }

    var checked = false
        set(value) {
            if (field != value) {
                field = value
                update()
            }
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        update()
    }

    private fun update() {
        advanced.isChecked = checked
        welcome.setText(ctx.getBrandedString(mode.msg))
        if (mode.on != null) {
            advanced.visibility = View.VISIBLE
            advancedText.visibility = View.VISIBLE
            advancedText.setText(if (checked) mode.on!! else mode.off!!)
            advanced.setOnClickListener {
                checked = !checked
            }
        } else {
            advanced.visibility = View.GONE
            advancedText.visibility = View.GONE
            checked = false
        }
    }

    private val welcome by lazy { findViewById(R.id.main_welcome) as TextView }
    private val advanced by lazy { findViewById(R.id.main_advanced) as ASwitchCompat }
    private val advancedText by lazy { findViewById(R.id.main_advanced_text) as TextView }

}
