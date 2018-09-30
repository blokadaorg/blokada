package filter

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import com.github.salomonbrys.kodein.instance
import core.Commands
import core.Filter
import core.UpdateFilter
import gs.environment.inject
import gs.property.I18n

class AFilterActor(
        initialFilter: Filter,
        private val v: AFilterView
) {
    private val dialog by lazy { v.context.inject().instance<AFilterAddDialog>() }
    private val cmd by lazy { v.context.inject().instance<Commands>() }
    private val i18n by lazy { v.context.inject().instance<I18n>() }

    var filter = initialFilter
        set(value) {
            field = value
            update()
        }

    init {
        update()
        v.setOnClickListener ret@{
            dialog.onSave = { newFilter ->
                cmd.send(UpdateFilter(newFilter.id, newFilter))
            }
            dialog.show(filter)
        }
        v.onDelete = {
            if (filter.id.startsWith("b_")) {
                // Hide default Blokada filters instead of deleting them, so they dont reappear on refresh
                filter = filter.alter(newHidden = true, newActive = false)
                cmd.send(UpdateFilter(filter.id, filter))
            } else {
                cmd.send(UpdateFilter(filter.id, null))
            }
        }
        v.showDelete = true
        v.onSwitched = { active ->
            filter = filter.alter(newActive = active)
            cmd.send(UpdateFilter(filter.id, filter))
        }
    }

    private fun update() {
        v.name = filter.customName ?: i18n.localisedOrNull("filters_${filter.id}_name") ?: sourceToName(v.context, filter.source)
        v.description = filter.customComment ?: i18n.localisedOrNull("filters_${filter.id}_comment")
        v.active = filter.active

        when {
            filter.source.id == "app" -> {
                v.multiple = false
                v.icon = sourceToIcon(v.context, filter.source.source)
                v.counter = null
                v.source = filter.source.source
                v.credit = null
            }
            filter.source.id == "single" -> {
                v.icon = null
                v.multiple = false
                v.counter = null
                v.source = null
                v.credit = null
            }
            else -> {
                v.icon = null
                v.multiple = true
//            v.counter = if (filter.hosts.isNotEmpty()) filter.hosts.size else null

                // Credit
                val credit = filter.credit
                v.credit = try {
                    Intent(Intent.ACTION_VIEW, Uri.parse(credit))
                } catch (e: Exception) {
                    null
                }
                v.credit?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                // Host
                val host = filter.source
                v.source = host.source
            }
        }
    }
}

internal fun sourceToIcon(ctx: android.content.Context, source: String): Drawable? {
    return try {
        ctx.packageManager.getApplicationIcon(
                ctx.packageManager.getApplicationInfo(source, PackageManager.GET_META_DATA)
        )
    } catch (e: Exception) {
        null
    }
}
