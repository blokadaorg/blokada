package filter

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import com.github.salomonbrys.kodein.instance
import core.ktx
import gs.environment.inject
import gs.property.I18n
import tunnel.Filter


class AFilterActor(
        initialFilter: Filter,
        initialSwitchEnabled: Boolean,
        private val v: AFilterView
) {
    private val dialog by lazy { v.context.inject().instance<AFilterAddDialog>() }
    private val i18n by lazy { v.context.inject().instance<I18n>() }
    private val t by lazy { v.context.inject().instance<tunnel.Main>() }

    var filter = initialFilter
        set(value) {
            field = value
            update()
        }

    var switchEnabled = initialSwitchEnabled

    init {
        update()
        v.setOnClickListener ret@ {
//            dialog.onSave = { newFilter ->
//                t.putFilter(v.context.ktx("filter:save"), newFilter)
//            }
//            dialog.show(filter)
        }
        v.onDelete = {
            if (filter.id.startsWith("b_")) {
                // Hide default Blokada filters instead of deleting them, so they dont reappear on refresh
                filter = filter.copy(hidden = true, active = false)
                t.putFilter(v.context.ktx("filter:delete:hide"), filter)
            } else {
                t.removeFilter(v.context.ktx("filter:delete"), filter)
            }
        }
        v.showDelete = true
        v.onSwitched = { active ->
            filter = filter.copy(active = active)
            t.putFilter(v.context.ktx("filter:onSwitch"), filter, sync = false)
        }
    }

    private fun update() {
        v.name = filter.customName ?: i18n.localisedOrNull("filters_${filter.id}_name") ?: sourceToName(v.context, filter.source)
        v.description = filter.customComment ?: i18n.localisedOrNull("filters_${filter.id}_comment")
        v.active = filter.active
        v.switchEnabled = switchEnabled

        if (filter.source.id == "app") {
            v.multiple = false
            v.icon = sourceToIcon(v.context, filter.source.source)
            v.counter = null
            v.source = filter.source.source
            v.credit = null
        } else if (filter.source.id == "single") {
            v.icon = null
            v.multiple = false
            v.counter = null
            v.source = null
            v.credit = null
        } else {
            v.icon = null
            v.multiple = true
//            v.counter = if (filter.hosts.isNotEmpty()) filter.hosts.size else null

            // Credit
            val credit = filter.credit
            v.credit = try {
                Intent(Intent.ACTION_VIEW, Uri.parse(credit))
            } catch (e: Exception) { null }
            v.credit?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // Host
            val host = filter.source
            v.source = host.source
        }
    }
}

internal fun sourceToIcon(ctx: android.content.Context, source: String): Drawable? {
    return try {
        ctx.packageManager.getApplicationIcon(
                ctx.packageManager.getApplicationInfo(source, PackageManager.GET_META_DATA)
        )
    } catch (e: Exception) { null }
}
