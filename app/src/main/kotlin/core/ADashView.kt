package core

import android.content.Context
import android.util.AttributeSet
import gs.presentation.doAfter
import org.blokada.R


class ADashView(
        ctx: Context,
        attributeSet: AttributeSet
) : android.widget.LinearLayout(ctx, attributeSet) {

    var iconRes: Int = R.drawable.ic_info
        set(value) {
            setIcon(value, { field = value })
        }

    var checked: Boolean? = null
        set(value) { when {
            value == null -> fromChecked { field = value }
            else -> setChecked(value, {
                val old = field
                field = value
                if (old != value) onChecked(value)
            })
        }}

    var text: String? = null
        set(value) { when (value) {
                field -> Unit
                null -> hideText()
                else -> showText(value)
            }

            field = value
        }

    var active = true
        set(value) { when {
            field == value -> Unit
            value == true -> toActive { field = value }
            else -> fromActive { field = value }
        }}

    var emphasized = true
        set(value) {
            field = value
            if (emphasized) iconView.setColorFilter(context.resources.getColor(R.color.colorAccent))
            else iconView.setColorFilter(context.resources.getColor(R.color.colorActive))
        }

    var onChecked = { active: Boolean -> }
    var onClick = {}
    var onLongClick = {}

    var showClickAnim = true

    private val iconView by lazy { findViewById(R.id.dash_icon) as android.widget.ImageView }
    private val switchView by lazy { findViewById(R.id.dash_switch) as android.support.v7.widget.SwitchCompat }
    private val textView by lazy { findViewById(R.id.dash_text) as android.widget.TextView }
    private val inter = android.view.animation.AccelerateDecelerateInterpolator()
    private val dur = 80L

    override fun onFinishInflate() {
        super.onFinishInflate()
        if (text == null) hideText()

        switchView.setOnClickListener {
            checked = !checked!!
        }
        var canClick = true
        setOnClickListener {
            if (!canClick) // Anim in progress
            else if (showClickAnim) {
                canClick = false
                rotate(-15f, {
                    rotate(30f, {
                        rotate(-15f, {
                            onClick()
                            canClick = true
                        })
                    })
                })
            } else onClick()
        }
        setOnLongClickListener { onLongClick(); true }
    }

    private fun rotate(how: Float, after: () -> Unit) {
        iconView.animate().rotationBy(how).setInterpolator(inter).setDuration(dur).doAfter(after)
    }

    private fun hideText() {
        textView.visibility = android.view.View.GONE
    }

    private fun showText(text: String) {
        textView.visibility = android.view.View.VISIBLE
        textView.text = android.text.Html.fromHtml(text)
    }

    private fun setIcon(iconRes: Int, after: () -> Unit) {
        iconView.visibility = android.view.View.VISIBLE
        switchView.visibility = android.view.View.GONE
        iconView.setImageResource(iconRes)
        after()
    }

    private fun setChecked(checked: Boolean, after: () -> Unit) {
        iconView.visibility = android.view.View.GONE
        switchView.visibility = android.view.View.VISIBLE
        switchView.isChecked = checked
        after()
    }

    private fun fromChecked(after: () -> Unit) {
        iconView.visibility = android.view.View.VISIBLE
        switchView.visibility = android.view.View.GONE
        after()
    }

    private fun toActive(after: () -> Unit) {
        iconView.alpha = 1.0f
        switchView.alpha = 1.0f
        textView.alpha = 1.0f
        switchView.isEnabled = true
        after()
    }

    private fun fromActive(after: () -> Unit) {
        iconView.alpha = 0.2f
        switchView.alpha = 0.2f
        textView.alpha = 0.2f
        switchView.isEnabled = false
        after()
    }
}
