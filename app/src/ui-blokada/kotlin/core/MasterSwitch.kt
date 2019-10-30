package core

import android.content.Context
import android.os.Handler
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import gs.presentation.LayoutViewBinder
import gs.presentation.doAfter
import gs.property.I18n
import io.ghyeok.stickyswitch.widget.StickySwitch
import org.blokada.R


abstract class MasterSwitchVB
    : LayoutViewBinder(R.layout.masterswitchview), Stepable, Navigable {

    abstract fun attach(view: MasterSwitchView)
    open fun detach(view: MasterSwitchView) = Unit

    protected var view: MasterSwitchView? = null

    override fun attach(view: View) {
        view as MasterSwitchView
        this.view = view
        attach(view)
    }

    override fun detach(view: View) {
        view as MasterSwitchView
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

class MasterSwitchView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.masterswitchview_content, this)
    }

    private val i18n by lazy { context.ktx("MasterSwitchView").di().instance<I18n>() }

    private val stateView = findViewById<TextView>(R.id.byte_state)
    private val switchView = findViewById<StickySwitch>(R.id.sticky_switch)
    private val lineView = findViewById<ImageView>(R.id.line)

    private var switched: Boolean? = null

    private val hideLabelHandler = Handler {
//        stateView.animate().setDuration(400).alpha(0.0f)
        true
    }

    fun state(state: Resource?, color: Resource? = null, animate: Boolean = true) {
        hideLabelHandler.removeMessages(0)
        hideLabelHandler.sendEmptyMessageDelayed(0, 5000)

        val label = when {
            state == null -> ""
            state.hasResId() -> i18n.getString(state.getResId())
            else -> state.getString()
        }

        if (animate) {
            stateView.text = label
            stateView.alpha = 1f
            stateView.animate().setDuration(100).scaleY(1.2f).scaleX(1.2f).alpha(0.0f).doAfter {
                stateView.scaleY = 1f
                stateView.scaleX = 1f
                stateView.alpha = 1f
            }
        } else stateView.text = label

        when {
            color == null -> stateView.setTextColor(resources.getColor(R.color.colorActive))
            color.hasResId() -> stateView.setTextColor(resources.getColor(color.getResId()))
            else -> stateView.setTextColor(color.getColor())
        }
    }


    fun switch(switched: Boolean?) {
        this.switched = switched
        when {
            switched == null -> {
                switchView.visibility = View.GONE
            }
            switched -> {
                switchView.visibility = View.VISIBLE
                switchView.setDirection(StickySwitch.Direction.RIGHT)
//                switchView.isChecked = switched
            }
            else -> {
                switchView.visibility = View.VISIBLE
                switchView.setDirection(StickySwitch.Direction.LEFT)
//                switchView.isChecked = switched
            }
        }
    }

    fun line(variant: Int) {
        val color = when(variant) {
            0 -> R.color.colorProtectionLow
            1 -> R.color.colorProtectionMedium
            2 -> R.color.colorProtectionHigh
            else -> R.color.colorProtectionVeryHigh
        }

        lineView.setImageResource(color)
    }

    fun onTap(tap: () -> Unit) {
        setOnClickListener { tap() }
    }

    fun onSwitch(switch: (Boolean) -> Unit) {
        switchView.setOnClickListener {
            it as StickySwitch
            switch(it.getDirection() == StickySwitch.Direction.RIGHT)
        }
    }

    fun isSwitched(): Boolean? {
        return if (switchView.visibility == View.GONE) null else switchView.getDirection() == StickySwitch.Direction.RIGHT
    }

}

