package org.blokada.presentation

import android.content.Context
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import org.blokada.framework.di
import org.blokada.property.State
import org.blokada.ui.app.Dash

val DASH_ID_HOSTS_COUNT = "tunnel_hosts"

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
        return ctx.resources.getString(R.string.tunnel_ads_blocked, blocked)
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
        return ctx.resources.getString(R.string.tunnel_hosts_count, count)
    }
}

