package core

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.widget.SwitchCompat
import com.github.salomonbrys.kodein.instance
import gs.presentation.LayoutViewBinder
import gs.presentation.doAfter
import gs.property.I18n
import org.blokada.R


abstract class ByteVB()
    : LayoutViewBinder(R.layout.byteview), Stepable, Navigable {

    abstract fun attach(view: ByteView)
    open fun detach(view: ByteView) = Unit

    protected var view: ByteView? = null

    override fun attach(view: View) {
        view as ByteView
        this.view = view
        attach(view)
    }

    override fun detach(view: View) {
        view as ByteView
        this.view = null
        detach(view)
    }

    override fun enter() {
        view?.run {
            when (isSwitched()) {
                true -> switch(false)
                false -> switch(true)
                else -> performClick()
            }
        }
    }

    override fun focus() {
    }

    override fun exit() = Unit

    override fun up() = Unit
    override fun down() = Unit
    override fun left() = Unit
    override fun right() = Unit

}

class ByteView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.byteview_content, this)
    }

    private val i18n by lazy { context.ktx("ByteView").di().instance<I18n>() }

    private val rootView = findViewById<ViewGroup>(R.id.byte_root)
    private val labelView = findViewById<TextView>(R.id.byte_label)
    private val iconView = findViewById<ImageView>(R.id.byte_icon)
    private val stateView = findViewById<TextView>(R.id.byte_state)
    private val arrowView = findViewById<ImageView>(R.id.byte_arrow)
    private val switchView = findViewById<SwitchCompat>(R.id.byte_switch)

    private var important = false
    private var switched: Boolean? = null

    fun label(label: Resource?, color: Resource? = null, animate: Boolean = true) {
        val label = when {
            label == null -> ""
            label.hasResId() -> i18n.getString(label.getResId())
            else -> label.getString()
        }

        if (animate) {
            labelView.text = label
            labelView.animate().setDuration(100).scaleY(1.2f).scaleX(1.2f).alpha(0.0f).doAfter {
                labelView.scaleY = 1f
                labelView.scaleX = 1f
                labelView.alpha = 1f
            }
        } else labelView.text = label

        when {
            color == null -> labelView.setTextColor(resources.getColor(R.color.colorActive))
            color.hasResId() -> labelView.setTextColor(resources.getColor(color.getResId()))
            else -> labelView.setTextColor(color.getColor())
        }
    }

    fun state(state: Resource?, color: Resource? = null, smallcap: Boolean = false) {
        when {
            state == null -> stateView.visibility = View.GONE
            state.hasResId() -> {
                stateView.visibility = View.VISIBLE
                if (smallcap) stateView.text = i18n.getString(state.getResId()).toLowerCase()
                else stateView.text = i18n.getString(state.getResId())
            }
            else -> {
                stateView.visibility = View.VISIBLE
                if (smallcap) stateView.text = state.getString().toLowerCase()
                else stateView.text = state.getString()
            }
        }

        when {
            color == null -> stateView.setTextColor(resources.getColor(R.color.colorInactive))
            color.hasResId() -> stateView.setTextColor(resources.getColor(color.getResId()))
            else -> stateView.setTextColor(color.getColor())
        }
    }

    fun icon(icon: Resource?, color: Resource? = Resource.ofResId(R.color.colorText)) {
        when {
            icon == null -> {
                iconView.visibility = View.INVISIBLE
            }
            icon.hasResId() -> {
                iconView.setImageResource(icon.getResId())
                iconView.visibility = View.VISIBLE
            }
            else -> {
                iconView.setImageDrawable(icon.getDrawable())
                iconView.visibility = View.VISIBLE
            }
        }

        when {
            color == null -> iconView.setColorFilter(resources.getColor(android.R.color.transparent))
            color.hasResId() -> iconView.setColorFilter(resources.getColor(color.getResId()))
            else -> iconView.setColorFilter(color.getColor())
        }
    }

    fun arrow(label: Resource?, color: Resource? = Resource.ofResId(R.color.colorAccent)) {
        when {
            label == null -> arrowView.visibility = View.GONE
            label.hasResId() -> {
                arrowView.visibility = View.VISIBLE
                arrowView.setImageResource(label.getResId())
            }
            else -> {
                arrowView.visibility = View.VISIBLE
                arrowView.setImageDrawable(label.getDrawable())
            }
        }

//        when {
//            color == null -> arrowView.setTextColor(resources.getColor(R.color.colorInactive))
//            color.hasResId() -> arrowView.setTextColor(resources.getColor(color.getResId()))
//            else -> arrowView.setTextColor(color.getColor())
//        }
    }

    fun switch(switched: Boolean?) {
        this.switched = switched
        setBackground()
        when {
            switched == null -> {
                switchView.visibility = View.GONE
            }
            switched -> {
                switchView.visibility = View.VISIBLE
                switchView.isChecked = switched
            }
            else -> {
                switchView.visibility = View.VISIBLE
                switchView.isChecked = switched
            }
        }
    }

    fun alternative(alternative: Boolean) {
        rootView.setBackgroundResource(R.drawable.bg_dashboard_item_alternative)
    }

    fun important(important: Boolean) {
        this.important = important
        setBackground()
    }

    fun onTap(tap: () -> Unit) {
        setOnClickListener { tap() }
    }

    fun onArrowTap(tap: () -> Unit) {
        arrowView.setOnClickListener { tap() }
    }

    fun onIconTap(tap: () -> Unit) {
        iconView.setOnClickListener { tap() }
    }

    fun onSwitch(switch: (Boolean) -> Unit) {
        switchView.setOnClickListener {
            it as SwitchCompat
            switch(it.isChecked)
        }
    }

    fun isSwitched(): Boolean? {
        return if (switchView.visibility == View.GONE) null else switchView.isChecked
    }

    private fun setBackground() {
        val bg = when {
            important -> R.drawable.bg_dashboard_item_important
            switched == false -> R.drawable.bg_dashboard_item_inactive
            else -> R.drawable.bg_dashboard_item
        }
        rootView.setBackgroundResource(bg)
    }
}

