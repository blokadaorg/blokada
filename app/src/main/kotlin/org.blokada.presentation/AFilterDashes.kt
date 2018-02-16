package org.blokada.presentation

import android.app.Activity
import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.provider
import com.github.salomonbrys.kodein.with
import nl.komponents.kovenant.task
import org.blokada.R
import gs.environment.ActivityProvider
import org.blokada.property.Filter
import org.blokada.property.State
import org.blokada.framework.IWhen
import org.blokada.framework.di
import org.blokada.ui.app.Dash
import org.blokada.ui.app.UiState

val DASH_ID_BLACKLIST = "filter_blacklist"
val DASH_ID_WHITELIST = "filter_whitelist"

private val KCTX = "filter-dashes"

class DashFilterBlacklist(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(DASH_ID_BLACKLIST,
        R.drawable.ic_shield_outline,
        ctx.getString(R.string.filter_blacklist_desc),
        text = ctx.getString(R.string.filter_blacklist_text_none),
        menuDashes = Triple(AddBlacklist(ctx, s), GenerateBlacklist(ctx, s), null),
        onDashOpen = { task(ctx.di().with(KCTX).instance()) {
            var changed = false
            s.filters().filter { !it.whitelist }.forEach {
                if (it.hosts.isEmpty()) {
                    it.hosts = it.source.fetch()
                    changed = true
                }
            }
            if (changed) s.filters %= s.filters()
        }},
        hasView = true
) {
    private var listener: IWhen? = null

    init {
        listener = s.filters.doOnUiWhenSet().then {
            update(s.filters().filter { it.active && !it.whitelist })
        }
    }

    private fun update(filters: List<Filter>) {
        if (filters.isEmpty()) text = ctx.getString(R.string.filter_blacklist_text_none)
        else text = ctx.resources.getQuantityString(R.plurals.filter_blacklist_text, filters.size, filters.size)
    }

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.view_customlist, parent as ViewGroup, false)
        if (view is AFilterListView) {
            val activity: ActivityProvider<Activity> = ctx.di().instance()
//            view.landscape = activity.getActivity()?.landscape ?: false
            // TODO
            view.whitelist = false
        }
        return view
    }
}

class DashFilterWhitelist(
        val ctx: Context,
        val s: State = ctx.di().instance(),
        val ui: UiState = ctx.di().instance()
) : Dash(DASH_ID_WHITELIST,
        R.drawable.ic_verified,
        ctx.getString(R.string.filter_whitelist_desc),
        text = ctx.getString(R.string.filter_whitelist_text_none),
        menuDashes = Triple(
                AddWhitelist(ctx, s), GenerateWhitelist(ctx, s), ShowSystemAppsWhitelist(ctx, ui)
        ),
        onDashOpen = { task(ctx.di().with(KCTX).instance()) {
            var changed = false
            s.filters().filter { it.whitelist }.forEach {
                if (it.hosts.isEmpty()) {
                    it.hosts = it.source.fetch()
                    changed = true
                }
            }
            if (changed) s.filters %= s.filters()
        }},
        hasView = true
) {

    private var listener: IWhen? = null

    init {
        listener = s.filters.doOnUiWhenSet().then {
            update(s.filters().filter { it.active && it.whitelist })
        }
    }

    private fun update(filters: List<Filter>) {
        if (filters.isEmpty()) text = ctx.getString(R.string.filter_whitelist_text_none)
        else text = ctx.resources.getQuantityString(R.plurals.filter_whitelist_text, filters.size, filters.size)
    }

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.view_customlist, parent as ViewGroup, false)
        if (view is AFilterListView) {
            val activity: ActivityProvider<Activity> = ctx.di().instance()
//            view.landscape = activity.getActivity()?.landscape ?: false
            // TODO
            view.whitelist = true
        }
        return view
    }
}

class AddBlacklist(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash (
        "filter_blacklist_add",
        R.drawable.ic_filter_add,
        onClick = {
            val dialogProvider: () -> AFilterAddDialog = ctx.di().provider()
            val dialog: AFilterAddDialog = dialogProvider()
            dialog.onSave = { newFilter ->
                newFilter.whitelist = false
                s.filters %= s.filters() + newFilter
            }
            dialog.show(null, whitelist = false)
            false
        }
)

class AddWhitelist(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash (
        "filter_whitelist_add",
        R.drawable.ic_filter_add,
        onClick = {
            val dialogProvider: () -> AFilterAddDialog = ctx.di().provider()
            val dialog: AFilterAddDialog = dialogProvider()
            dialog.onSave = { newFilter ->
                newFilter.whitelist = true
                s.filters %= s.filters() + newFilter
            }
            dialog.show(null, whitelist = true)
            false
        }
)

class GenerateWhitelist(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash (
        "filter_whitelist_generate",
        R.drawable.ic_tune,
        onClick = {
            val dialogProvider: () -> AFilterGenerateDialog = ctx.di().provider(true)
            val dialog: AFilterGenerateDialog = dialogProvider()
            dialog.show()
            false
        }
)

class GenerateBlacklist(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash (
        "filter_blacklist_generate",
        R.drawable.ic_tune,
        onClick = {
            val dialogProvider: () -> AFilterGenerateDialog = ctx.di().provider(false)
            val dialog: AFilterGenerateDialog = dialogProvider()
            dialog.show()
            false
        }
)

class ShowSystemAppsWhitelist(
        val ctx: Context,
        val ui: UiState = ctx.di().instance()
) : Dash (
        "filter_whitelist_showsystem",
        icon = false,
        isSwitch = true
) {
    override var checked = false
        set(value) { if (field != value) {
            field = value
            ui.showSystemApps %= value
            onUpdate.forEach { it() }
        }}

    private val listener: Any
    init {
        listener = ui.showSystemApps.doOnUiWhenSet().then {
            checked = ui.showSystemApps()
        }
    }
}
