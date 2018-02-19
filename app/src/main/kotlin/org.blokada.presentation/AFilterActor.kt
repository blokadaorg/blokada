package org.blokada.presentation

import android.content.Intent
import android.net.Uri
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import org.blokada.R
import org.blokada.property.*


class AFilterActor(
        initialFilter: Filter,
        private val v: AFilterView
) {
    private val dialog by lazy { v.context.inject().instance<AFilterAddDialog>() }
    private val s by lazy { v.context.inject().instance<State>() }

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
            s.filters %= s.filters()
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
            if (filter.localised?.comment == null && s.tunnelActiveEngine() != "lollipop")
                v.description = v.context.getString(R.string.filter_edit_app_unsupported)
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

            // Credit source
            val source = filter.source
            v.credit = try {
                Intent(Intent.ACTION_VIEW, when (source) {
                    is FilterSourceLink -> Uri.parse(source.source?.toExternalForm())
                    is FilterSourceUri -> source.source
                    else -> throw Exception("no source")
                })
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
