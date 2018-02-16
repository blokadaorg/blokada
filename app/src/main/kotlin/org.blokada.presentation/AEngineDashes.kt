package org.blokada.presentation

import android.app.Activity
import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import gs.environment.ActivityProvider
import org.blokada.property.State
import org.blokada.framework.di
import org.blokada.ui.app.Dash

val DASH_ID_HOSTS_COUNT = "tunnel_hosts"
val DASH_ID_ENGINE_SELECTED = "tunnel_selected"

class TunnelDashAdsBlocked(
        val ctx: Context,
        val t: State = ctx.di().instance()
) : Dash("tunnel_ads",
        R.drawable.ic_block,
        ctx.getString(R.string.tunnel_ads_desc)
) {

    private val listener: Any
    init {
        text = getBlockedString(0)
        listener = t.tunnelAdsCount.doOnUiWhenSet().then {
            text = getBlockedString(t.tunnelAdsCount())
        } // TODO: think item lifetime vs listener leak
    }

    private fun getBlockedString(blocked: Int): String {
        return ctx.resources.getQuantityString(R.plurals.tunnel_ads_blocked, blocked, blocked)
    }
}

class TunnelDashHostsCount(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(DASH_ID_HOSTS_COUNT,
        R.drawable.ic_counter,
        ctx.getBrandedString(R.string.tunnel_hosts_desc),
        onClick = { s.filters.refresh(); s.filtersCompiled.refresh(); true }
) {

    private val listener: Any
    init {
        text = getCountString(0)
        listener = s.filtersCompiled.doOnUiWhenSet().then {
            text = getCountString(s.filtersCompiled().size)
        } // TODO: think item lifetime vs listener leak
    }

    private fun getCountString(count: Int): String {
        return ctx.resources.getQuantityString(R.plurals.tunnel_hosts_count, count, count)
    }
}

class TunnelDashEngineSelected(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(DASH_ID_ENGINE_SELECTED,
        R.drawable.ic_tune,
        ctx.getBrandedString(R.string.tunnel_selected_desc),
        hasView = true
) {

    private var listener: Any? = null
    init {
        text = "-"
        listener = s.tunnelActiveEngine.doOnUiWhenSet().then {
            update(s.tunnelActiveEngine())
        }
    }

    private fun update(engineId: String) {
        text = s.tunnelEngines().firstOrNull { it.id == engineId }?.text ?: engineId
    }

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.view_enginegrid, parent as ViewGroup, false)
        if (view is AEngineGridView) {
            val activity: ActivityProvider<Activity> = ctx.di().instance()
//            view.landscape = activity.get().landscape ?: false
            // TODO
        }
        return view
    }
}
