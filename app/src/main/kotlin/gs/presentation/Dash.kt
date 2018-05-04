package gs.presentation

import android.content.Context
import android.support.v7.widget.SwitchCompat
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import gs.kar.R
import gs.property.IProperty
import gs.property.IWhen

/**
 * Represents basic view structure that can be embedded in lists or displayed independently, also as
 * a widget.
 */
interface Dash {
    fun createView(ctx: Context, parent: ViewGroup): View
    fun attach(view: View)
    fun detach(view: View)
}

interface CallbackDash : Dash {
    fun onAttached(attached: () -> Unit)
    fun onDetached(detached: () -> Unit)
}

typealias On = Boolean

abstract class ViewDash(
        val resId: Int
) : Dash {
    override fun createView(ctx: Context, parent: ViewGroup): View {
        return LayoutInflater.from(ctx).inflate(resId, parent, false)
    }
}

open class SwitchDash(
        val text: String,
        val property: IProperty<Boolean>
) : ViewDash(R.layout.dash_switch) {

    private var changeListener: IWhen? = null

    override fun attach(view: View) {
        val v = view as SwitchDashView
        v.text = text
        v.checked = property()
        v.onChecked = {
            property %= v.checked ?: property()
        }
        changeListener = property.doOnUiWhenChanged().then { v.checked = property() }
    }

    override fun detach(view: View) {
        val v = view as SwitchDashView
        v.onChecked = {}
        property.cancel(changeListener)
    }

}

class SwitchDashView(
        ctx: Context,
        attributeSet: AttributeSet
) : LinearLayout(ctx, attributeSet) {

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

    var onChecked = { active: Boolean -> }

    private val switchView by lazy { findViewById(R.id.dash_switch) as SwitchCompat }
    private val textView by lazy { findViewById(R.id.dash_text) as TextView }

    override fun onFinishInflate() {
        super.onFinishInflate()
        if (text == null) hideText()

        switchView.setOnClickListener {
            checked = !checked!!
        }
    }

    private fun hideText() {
        textView.visibility = View.GONE
    }

    private fun showText(text: String) {
        textView.visibility = View.VISIBLE
        textView.text = android.text.Html.fromHtml(text)
    }

    private fun setChecked(checked: Boolean, after: () -> Unit) {
        switchView.visibility = View.VISIBLE
        switchView.isChecked = checked
        after()
    }

    private fun fromChecked(after: () -> Unit) {
        switchView.visibility = View.GONE
        after()
    }
}

abstract class IconDash(
        val onClick: () -> Unit = {},
        val iconRes: Int? = null
) : ViewDash(R.layout.dash_icon) {

    open fun attachIcon(v: IconDashView) {}
    open fun detachIcon(v: IconDashView) {}

    override fun attach(view: View) {
        view as IconDashView
        view.onClick = onClick
        if (iconRes != null) view.iconRes = iconRes
        attachIcon(view)
    }

    override fun detach(view: View) {
        val v = view as IconDashView
        v.onClick = {}
        detachIcon(v)
    }

}

class IconDashView(
        ctx: Context,
        attributeSet: AttributeSet
) : LinearLayout(ctx, attributeSet) {

    var iconRes: Int = R.drawable.ic_info
        set(value) {
            setIcon(value, { field = value })
        }

    var text: String? = null
        set(value) { when (value) {
                field -> Unit
                null -> hideText()
                else -> showText(value)
            }

            field = value
        }

    var emphasized = false
        set(value) {
            field = value
            if (emphasized) iconView.setColorFilter(context.resources.getColor(R.color.colorAccent))
            else iconView.setColorFilter(context.resources.getColor(R.color.colorActive))
        }

    var onClick = {}

    var showClickAnim = true

    private val iconView by lazy { findViewById(R.id.dash_icon) as ImageView }
    private val textView by lazy { findViewById(R.id.dash_text) as TextView }
    private val inter = AccelerateDecelerateInterpolator()
    private val dur = 80L

    override fun onFinishInflate() {
        super.onFinishInflate()
        if (text == null) hideText()

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
    }

    private fun rotate(how: Float, after: () -> Unit) {
        iconView.animate().rotationBy(how).setInterpolator(inter).setDuration(dur).doAfter(after)
    }

    private fun hideText() {
        textView.visibility = View.GONE
    }

    private fun showText(text: String) {
        textView.visibility = View.VISIBLE
        textView.text = android.text.Html.fromHtml(text)
    }

    private fun setIcon(iconRes: Int, after: () -> Unit) {
        iconView.visibility = View.VISIBLE
        iconView.setImageResource(iconRes)
        after()
    }
}
