package filter

import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.provider
import core.Dash
import core.Filters
import core.MainActivity
import core.UiState
import core.Commands
import core.Filter
import core.MonitorFilters
import core.UpdateFilter
import gs.environment.ComponentProvider
import gs.environment.inject
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.channels.consumeEach
import kotlinx.coroutines.experimental.launch
import org.blokada.R

val DASH_ID_BLACKLIST = "filter_blacklist"
val DASH_ID_WHITELIST = "filter_whitelist"

private val KCTX = "filter-dashes"

class DashFilterBlacklist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val cmd: Commands = ctx.inject().instance()
) : Dash(DASH_ID_BLACKLIST,
        R.drawable.ic_shield_outline,
        text = ctx.getString(R.string.filter_blacklist_text_none),
        menuDashes = Triple(AddBlacklist(ctx, s), GenerateBlacklist(ctx, s), null),
        onBack = { s.changed %= true },
        hasView = true
) {
    init {
        launch {
            cmd.subscribe(MonitorFilters()).consumeEach {
                launch(UI) { update(it.filter { it.active && !it.whitelist })}
            }
        }
    }

    private fun update(downloadedFilters: Collection<Filter>) {
        if (downloadedFilters.isEmpty()) text = ctx.getString(R.string.filter_blacklist_text_none)
        else text = ctx.resources.getString(R.string.filter_blacklist_text, downloadedFilters.size)
    }

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.view_customlist, parent as ViewGroup, false)
        if (view is AFilterListView) {
            val activity: ComponentProvider<MainActivity> = ctx.inject().instance()
            view.landscape = activity.get()?.landscape ?: false
            view.whitelist = false
        }
        return view
    }
}

class DashFilterWhitelist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val ui: UiState = ctx.inject().instance(),
        val cmd: Commands = ctx.inject().instance()
) : Dash(DASH_ID_WHITELIST,
        R.drawable.ic_verified,
        text = ctx.getString(R.string.filter_whitelist_text_none),
        menuDashes = Triple(
                AddWhitelist(ctx, s), GenerateWhitelist(ctx, s), ShowSystemAppsWhitelist(ctx, ui)
        ),
        onBack = { s.changed %= true },
        hasView = true
) {

    init {
        launch {
            cmd.subscribe(MonitorFilters()).consumeEach {
                launch(UI) { update(it.filter { it.active && it.whitelist })}
            }
        }
    }

    private fun update(downloadedFilters: List<Filter>) {
        if (downloadedFilters.isEmpty()) text = ctx.getString(R.string.filter_whitelist_text_none)
        else text = ctx.resources.getString(R.string.filter_whitelist_text, downloadedFilters.size)
    }

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.view_customlist, parent as ViewGroup, false)
        if (view is AFilterListView) {
            val activity: ComponentProvider<MainActivity> = ctx.inject().instance()
            view.landscape = activity.get()?.landscape ?: false
            view.whitelist = true
        }
        return view
    }
}

class AddBlacklist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val cmd: Commands = ctx.inject().instance()
) : Dash(
        "filter_blacklist_add",
        R.drawable.ic_filter_add,
        onClick = {
            val dialogProvider: () -> AFilterAddDialog = ctx.inject().provider()
            val dialog: AFilterAddDialog = dialogProvider()
            dialog.onSave = { newFilter ->
                cmd.send(UpdateFilter(newFilter.id, newFilter))
            }
            dialog.show(null, whitelist = false)
            false
        }
)

class AddWhitelist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val cmd: Commands = ctx.inject().instance()
) : Dash(
        "filter_whitelist_add",
        R.drawable.ic_filter_add,
        onClick = {
            val dialogProvider: () -> AFilterAddDialog = ctx.inject().provider()
            val dialog: AFilterAddDialog = dialogProvider()
            dialog.onSave = { newFilter ->
                cmd.send(UpdateFilter(newFilter.id, newFilter))
            }
            dialog.show(null, whitelist = true)
            false
        }
)

class GenerateWhitelist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance()
) : Dash(
        "filter_whitelist_generate",
        R.drawable.ic_tune,
        onClick = {
            val dialogProvider: () -> AFilterGenerateDialog = ctx.inject().provider(true)
            val dialog: AFilterGenerateDialog = dialogProvider()
            dialog.show()
            false
        }
)

class GenerateBlacklist(
        val ctx: Context,
        val s: Filters = ctx.inject().instance()
) : Dash(
        "filter_blacklist_generate",
        R.drawable.ic_tune,
        onClick = {
            val dialogProvider: () -> AFilterGenerateDialog = ctx.inject().provider(false)
            val dialog: AFilterGenerateDialog = dialogProvider()
            dialog.show()
            false
        }
)

class ShowSystemAppsWhitelist(
        val ctx: Context,
        val ui: UiState = ctx.inject().instance()
) : Dash(
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
