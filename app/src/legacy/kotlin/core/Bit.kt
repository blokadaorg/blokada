package core

import android.content.Context
import android.graphics.drawable.Drawable
import android.os.Handler
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.widget.SwitchCompat
import androidx.core.view.GestureDetectorCompat
import com.github.salomonbrys.kodein.instance
import gs.presentation.LayoutViewBinder
import gs.property.I18n
import org.blokada.R


class Resource private constructor(
        private val value: Any? = null,
        private val resId: Int? = null
) {
    companion object {
        fun of(string: String) = Resource(value = string)
        fun of(drawable: Drawable) = Resource(value = drawable)
        fun ofColor(color: Int) = Resource(value = color)
        fun ofResId(resId: Int) = Resource(resId = resId)
    }

    fun getDrawable() = value as Drawable
    fun getString() = value as String
    fun getColor() = value as Int
    fun getResId() = resId!!
    fun hasResId() = resId != null

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Resource

        if (value != other.value) return false
        if (resId != other.resId) return false

        return true
    }

    override fun hashCode(): Int {
        var result = value?.hashCode() ?: 0
        result = 31 * result + (resId ?: 0)
        return result
    }

}

fun Int.res() = Resource.ofResId(this)
fun String.res() = Resource.of(this)

abstract class BitVB(internal var onTap: (BitView) -> Unit = {})
    : LayoutViewBinder(R.layout.bitview), Stepable, Navigable {

    abstract fun attach(view: BitView)
    open fun detach(view: BitView) = Unit

    protected var view: BitView? = null

    override fun attach(view: View) {
        view as BitView
        this.view = view
        attach(view)
    }

    override fun detach(view: View) {
        view as BitView
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

class BitView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.bitview_content, this)
    }

    private val i18n by lazy { context.ktx("BitView").di().instance<I18n>() }

    private val containerView = findViewById<ViewGroup>(R.id.bit_container)
    private val unreadView = findViewById<ImageView>(R.id.bit_unread)
    private val labelView = findViewById<TextView>(R.id.bit_label)
    private val iconView = findViewById<ImageView>(R.id.bit_icon)
    private val switchView = findViewById<SwitchCompat>(R.id.bit_switch)
    private val stateView = findViewById<TextView>(R.id.bit_state)
    private val arrowView = findViewById<ImageView>(R.id.bit_arrow)

    private val detector = GestureDetectorCompat(context, object : GestureDetector.SimpleOnGestureListener() {
        override fun onFling(e1: MotionEvent?, e2: MotionEvent?, velocityX: Float, velocityY: Float): Boolean {
            return if (velocityX > 0) {
                performClick()
                true
            } else false
        }

        override fun onScroll(e1: MotionEvent?, e2: MotionEvent?, distanceX: Float, distanceY: Float): Boolean {
            return if (distanceX > 0) {
                performClick()
                true
            } else false
        }
    })

    private var alternative = false

//    fun enableAlternativeBackground() {
//        foldingView.initialize(500, resources.getColor(R.color.colorBackgroundLight), 0)
//        foldedContainerView.setBackgroundResource(R.drawable.bg_dashboard_item_alternative)
//        unfoldedContainerView.setBackgroundResource(R.drawable.bg_dashboard_item_unfolded_alternative)
//    }

    fun label(label: Resource?, color: Resource? = null) {
        labelView.text = when {
            label == null -> ""
            label.hasResId() -> i18n.getString(label.getResId())
            else -> label.getString()
        }

        when {
            color == null -> labelView.setTextColor(resources.getColor(R.color.colorText))
            color.hasResId() -> labelView.setTextColor(resources.getColor(color.getResId()))
            else -> labelView.setTextColor(color.getColor())
        }
    }

    fun state(state: Resource?, color: Resource? = null) {
        when {
            state == null -> stateView.visibility = View.GONE
            state.hasResId() -> {
                stateView.visibility = View.VISIBLE
                stateView.text = i18n.getString(state.getResId())
            }
            else -> {
                stateView.visibility = View.VISIBLE
                stateView.text = state.getString()
            }
        }

        when {
            color == null -> stateView.setTextColor(resources.getColor(R.color.colorAccent))
            color.hasResId() -> stateView.setTextColor(resources.getColor(color.getResId()))
            else -> stateView.setTextColor(color.getColor())
        }
    }

    fun icon(icon: Resource?, color: Resource? = Resource.ofResId(R.color.colorText)) {
        when {
            icon == null -> iconView.setImageResource(R.drawable.ic_info)
            icon.hasResId() -> iconView.setImageResource(icon.getResId())
            else -> iconView.setImageDrawable(icon.getDrawable())
        }

        when {
            color == null -> iconView.setColorFilter(resources.getColor(android.R.color.transparent))
            color.hasResId() -> iconView.setColorFilter(resources.getColor(color.getResId()))
            else -> iconView.setColorFilter(color.getColor())
        }
    }

    fun switch(switched: Boolean?) {
        when {
            switched == null -> {
                switchView.visibility = View.GONE
                if (!alternative) containerView.setBackgroundResource(R.drawable.bg_dashboard_item)
            }
            switched -> {
                switchView.visibility = View.VISIBLE
                switchView.isChecked = switched
                if (!alternative) containerView.setBackgroundResource(R.drawable.bg_dashboard_item)
            }
            else -> {
                switchView.visibility = View.VISIBLE
                switchView.isChecked = switched
                if (!alternative) containerView.setBackgroundResource(R.drawable.bg_dashboard_item_inactive)
            }
        }
    }

    fun arrow(arrow: Boolean) {
        arrowView.visibility = if (arrow) View.VISIBLE else View.GONE
    }

    fun alternative(alternative: Boolean) {
        containerView.setBackgroundResource(R.drawable.bg_dashboard_item_alternative)
        this.alternative = alternative
    }

    fun onTap(tap: () -> Unit) {
        setOnClickListener {
            containerView.setBackgroundResource(R.drawable.bg_dashboard_item_inactive)
            tap()
            Handler {
                if (alternative)
                    containerView.setBackgroundResource(R.drawable.bg_dashboard_item_alternative)
                else
                    containerView.setBackgroundResource(R.drawable.bg_dashboard_item)
                true
            }.sendEmptyMessageDelayed(0, 100)
        }
    }

    fun onSwitch(switch: (Boolean) -> Unit) {
        switchView.setOnCheckedChangeListener { compoundButton, b ->
            switch(b)
        }
    }

    fun isSwitched(): Boolean? {
        return if (switchView.visibility == View.GONE) null else switchView.isChecked
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return if (detector.onTouchEvent(event)) true
        else super.onTouchEvent(event)
    }
}

