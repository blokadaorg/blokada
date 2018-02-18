package org.blokada.presentation

import android.support.v4.content.ContextCompat.getColorStateList
import com.github.salomonbrys.kodein.instance
import org.blokada.main.Events
import gs.environment.Journal
import org.blokada.property.State
import org.obsolete.di
import org.blokada.R

/**
 *
 */
class AFabActor(
        private val fabView: AFloaterView,
        private val s: State,
        private val enabledStateActor: EnabledStateActor,
        private val contentActor: ContentActor
) : IEnabledStateActorListener {

    private val ctx by lazy { fabView.context }
    private val colorsActive by lazy { getColorStateList(ctx, R.color.fab_active) }
    private val colorsAccent by lazy { getColorStateList(ctx, R.color.fab_accent) }
    private val a by lazy { ctx.di().instance<Journal>() }

    init {
        contentActor.onDashOpen += { dash -> when {
            dash == null -> reset()
            dash.menuDashes.first != null -> {
                val d = dash.menuDashes.first!!
                enabledStateActor.listeners.remove(this)
                val icon = d.icon as Int
                fabView.icon = icon
                fabView.onClick = {
                    d.onClick?.invoke(d)
                    a.event(Events.Companion.CLICK_DASH(d.id))
                }
            }
            else -> fabView.icon = null
        }}

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
