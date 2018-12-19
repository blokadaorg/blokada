package gs.presentation

import android.widget.ImageView
import android.widget.LinearLayout
import org.blokada.R
import android.content.Context
import android.util.AttributeSet
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.View
import android.widget.TextView

@Deprecated("old dashboard going away")
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

