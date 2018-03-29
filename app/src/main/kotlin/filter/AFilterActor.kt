package filter

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import com.github.salomonbrys.kodein.instance
import core.Filter
import core.Filters
import core.IFilterSource
import gs.environment.inject


class AFilterActor(
        initialFilter: Filter,
        private val v: AFilterView
) {
    private val dialog by lazy { v.context.inject().instance<AFilterAddDialog>() }
    private val s by lazy { v.context.inject().instance<Filters>() }

    var filter = initialFilter
        set(value) {
            field = value
            update()
        }

    init {
        update()
        v.setOnClickListener ret@ {
            dialog.onSave = { newFilter ->
                s.filters %= s.filters().map { if (it == filter) newFilter else it }
            }
            dialog.show(filter)
        }
        v.onDelete = {
            s.filters %= s.filters().minus(filter)
        }
        v.showDelete = true
        v.onSwitched = { active ->
            filter.active = active
        }
    }

    private fun update() {
        v.name = filter.localised?.name ?: sourceToName(v.context, filter.source)
        v.description = filter.localised?.comment
        v.active = filter.active

        if (filter.source is FilterSourceApp) {
            v.multiple = false
            v.icon = sourceToIcon(v.context, filter.source)
            v.counter = null
            v.source = filter.source.toUserInput()
            v.credit = null
        } else if (filter.source is FilterSourceSingle) {
            v.icon = null
            v.multiple = false
            v.counter = null
            v.source = null
            v.credit = null
        } else {
            v.icon = null
            v.multiple = true
            v.counter = if (filter.hosts.isNotEmpty()) filter.hosts.size else null

            // Credit
            val credit = filter.credit
            v.credit = try {
                Intent(Intent.ACTION_VIEW, Uri.parse(credit))
            } catch (e: Exception) { null }
            v.credit?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // Host
            val host = filter.source
            v.source = when (host) {
                is FilterSourceLink -> host.source?.toExternalForm()
                is FilterSourceUri -> host.source?.toString()
                else -> null
            }
        }
    }
}

internal fun sourceToIcon(ctx: android.content.Context, source: IFilterSource): Drawable? {
    return when (source) {
        is FilterSourceApp -> { try {
            ctx.packageManager.getApplicationIcon(
                    ctx.packageManager.getApplicationInfo(source.source, PackageManager.GET_META_DATA)
            )
        } catch (e: Exception) { null }}
        else -> null
    }
}

