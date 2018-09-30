package core

import android.content.Context
import android.support.design.widget.FloatingActionButton
import android.support.v7.content.res.AppCompatResources.getColorStateList
import android.util.AttributeSet
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import gs.presentation.doAfter
import gs.presentation.toPx
import org.blokada.R

class AFloaterView(
        ctx: Context,
        attributeSet: AttributeSet
) : FloatingActionButton(ctx, attributeSet) {

    var onClick = {}

    var icon: Int? = R.drawable.ic_power
        set(value) {
            when (value) {
                field -> Unit
                null -> {
                    toHide { field = value }
                }
                else -> {
                    toHide {
                        setImageResource(value)
                        colorFilter = colorFilter //TODO
                        fromHide {
                            field = value
                        }
                    }
                }
            }
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setOnClickListener {
            rotate(-20f) {
                rotate(40f) {
                    rotate(-20f) {
                        onClick()
                    }
                }
            }
        }
    }

    private val inter = AccelerateInterpolator(3f)
    private val inter2 = DecelerateInterpolator(3f)
    private val inter3 = AccelerateDecelerateInterpolator()

    private fun toHide(after: () -> Unit) {
        animate().setInterpolator(inter).setDuration(200).translationY(resources.toPx(100)
                .toFloat()).doAfter(after)
    }

    private fun fromHide(after: () -> Unit) {
        animate().setInterpolator(inter2).setDuration(200).translationY(0f).doAfter(after)
    }

    private fun rotate(how: Float, after: () -> Unit) {
        animate().rotationBy(how).setInterpolator(inter3).setDuration(100).doAfter(after)
    }
}

class AFabActor(
        private val fabView: AFloaterView,
        private val s: Tunnel,
        private val enabledStateActor: EnabledStateActor,
        contentActor: ContentActor
) : IEnabledStateActorListener {

    private val ctx by lazy { fabView.context }
    private val colorsActive by lazy { getColorStateList(ctx, R.color.fab_active) }
    private val colorsAccent by lazy { getColorStateList(ctx, R.color.fab_accent) }

    init {
        contentActor.onDashOpen += { dash ->
            when {
                dash == null -> reset()
                dash.menuDashes.first != null -> {
                    val d = dash.menuDashes.first!!
                    enabledStateActor.listeners.remove(this)
                    val icon = d.icon as Int
                    fabView.icon = icon
                    fabView.onClick = {
                        d.onClick?.invoke(d)
                    }
                }
                else -> fabView.icon = null
            }
        }

        reset()
    }

    private fun reset() {
        enabledStateActor.listeners.add(this)
        enabledStateActor.update(s)
        fabView.icon = R.drawable.ic_power
        fabView.onClick = {
            s.enabled %= !s.enabled()
        }
    }

    override fun startActivating() {
        fabView.backgroundTintList = colorsActive
        fabView.isEnabled = false
        fabView.setColorFilter(ctx.resources.getColor(R.color.colorActive))
    }

    override fun startDeactivating() {
        fabView.backgroundTintList = colorsActive
        fabView.isEnabled = false
        fabView.setColorFilter(ctx.resources.getColor(R.color.colorActive))
    }

    override fun finishActivating() {
        fabView.backgroundTintList = colorsAccent
        fabView.isEnabled = true
        fabView.setColorFilter(ctx.resources.getColor(R.color.colorActive))
    }

    override fun finishDeactivating() {
        fabView.backgroundTintList = colorsActive
        fabView.isEnabled = true
        fabView.setColorFilter(ctx.resources.getColor(R.color.colorBackground))
    }

}
