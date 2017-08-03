package org.blokada.ui.app.android

import android.content.Context
import android.content.Intent
import android.support.v7.widget.SwitchCompat
import android.text.Html
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import org.blokada.lib.ui.R
import org.blokada.ui.framework.android.doAfter


class AFilterView(
        private val ctx: Context,
        attributeSet: AttributeSet?
) : FrameLayout(ctx, attributeSet) {

    var onDelete = {}
    var onLongTap = {}
    var onSwitched = { checked: Boolean -> }

    var multiple: Boolean = false
        set(value) {
            field = value
            if (multiple) iconView.setImageResource(R.drawable.ic_hexagon_multiple)
            else iconView.setImageResource(R.drawable.ic_hexagon)
        }

    var active: Boolean? = false
        set(value) {
            if (field == value) return
            if (value != null) {
                activeSwitch.visibility = View.VISIBLE
                activeSwitch.isChecked = value
                field = value
            } else {
                activeSwitch.visibility = View.GONE
                field = value
            }
        }

    var tapped: Boolean = false
        set(selected) {
            field = selected
            if (selected) {
                setBackgroundColor(ctx.resources.getColor(R.color.colorAccent))
                iconView.setColorFilter(ctx.resources.getColor(R.color.colorAccent))
            } else {
                setBackgroundColor(ctx.resources.getColor(R.color.colorBackground))
                iconView.setColorFilter(ctx.resources.getColor(R.color.colorActive))
            }
            name = name // To refresh
        }

    var name: String = ""
        set(value) {
            field = value
            if (tapped) {
                nameView.text = value
                nameView.setTextColor(ctx.resources.getColor(R.color.colorAccent))
            } else {
                nameView.text = value
                nameView.setTextColor(ctx.resources.getColor(R.color.colorActive))
            }
        }

    var description: String? = null
        set(value) {
            field = value
            if (value != null) {
                descView.text = Html.fromHtml(value)
                descView.visibility = View.VISIBLE
            } else {
                descView.visibility = View.GONE
            }
            updateDeleteIcon()
        }

    var source: String? = null
        set(value) {
            field = value
            if (value != null) {
                hostView.visibility = View.VISIBLE
                hostView.text = value
            } else {
                hostView.visibility = View.GONE
            }
        }

    var counter: Int? = null
        set(value) {
            field = value
            if (value != null) {
                counterView.visibility = View.VISIBLE
                counterIcon.visibility = View.VISIBLE
                counterView.text = ctx.resources.getQuantityString(R.plurals.tunnel_hosts_count, value, value)
            } else {
                counterView.visibility = View.GONE
                counterIcon.visibility = View.GONE
            }
            updateDeleteIcon()
        }

    var credit: Intent? = null
        set(value) {
            field = value
            if (value != null) {
                sourceIcon.visibility = View.VISIBLE
            } else {
                sourceIcon.visibility = View.GONE
            }
            updateDeleteIcon()
        }

    var showDelete: Boolean = false
        set(value) {
            field = value
            updateDeleteIcon()
        }

    var recommended: Boolean = false
        set(value) {
            field = value
            if (value) {
                nameView.text = ctx.resources.getString(R.string.filter_recommended, name)
            } else {
                nameView.text = name
            }
        }

    private val iconView by lazy { findViewById(R.id.filter_icon) as ImageView }
    private val nameView by lazy { findViewById(R.id.filter_name) as TextView }
    private val hostView by lazy { findViewById(R.id.filter_host) as TextView }
    private val descView by lazy { findViewById(R.id.filter_desc) as TextView }
    private val counterView by lazy { findViewById(R.id.filter_counter) as TextView }
    private val counterIcon by lazy { findViewById(R.id.filter_counter_icon) }
    private val sourceIcon by lazy { findViewById(R.id.filter_source) }
    private val deleteIcon by lazy { findViewById(R.id.filter_delete) }
    private val deleteSmallIcon by lazy { findViewById(R.id.filter_delete_small) }
    private val activeSwitch by lazy { findViewById(R.id.filter_active) as SwitchCompat }

    private val inter = AccelerateDecelerateInterpolator()
    private val dur = 80L
    private fun rotate(view: View, how: Float, after: () -> Unit) {
        view.animate().rotationBy(how).setInterpolator(inter).setDuration(dur).doAfter(after)
    }

    override fun onFinishInflate() {
        super.onFinishInflate()
        descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        setOnLongClickListener { onLongTap(); true }

        deleteIcon.setOnClickListener {
            rotate(deleteIcon, -15f, {
                rotate(deleteIcon, 30f, {
                    rotate(deleteIcon, -15f, {
                        onDelete()
                    })
                })
            })
        }
        deleteSmallIcon.setOnClickListener {
            rotate(deleteSmallIcon, -15f, {
                rotate(deleteSmallIcon, 30f, {
                    rotate(deleteSmallIcon, -15f, {
                        onDelete()
                    })
                })
            })
        }
        sourceIcon.setOnClickListener {
            rotate(sourceIcon, -15f, {
                rotate(sourceIcon, 30f, {
                    rotate(sourceIcon, -15f, {
                        ctx.startActivity(credit)
                    })
                })
            })
        }
        activeSwitch.setOnClickListener {
            active = !active!!
            onSwitched(active!!)
        }
        tapped = false
        multiple = false
        description = null
        source = null
        counter = null
        credit = null
        showDelete = false
        active = null
    }

    private fun updateDeleteIcon() {
        if (!showDelete) {
            deleteIcon.visibility = View.GONE
            deleteSmallIcon.visibility = View.GONE
        } else if (counter != null || credit != null || description != null) {
            deleteIcon.visibility = View.VISIBLE
            deleteSmallIcon.visibility = View.GONE
        } else {
            deleteIcon.visibility = View.GONE
            deleteSmallIcon.visibility = View.VISIBLE
        }
    }
}
