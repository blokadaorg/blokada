package filter

import android.content.Context
import android.support.v7.widget.RecyclerView
import android.support.v7.widget.StaggeredGridLayoutManager
import android.util.AttributeSet
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import core.Filters
import core.UiState
import core.Commands
import core.Filter
import core.MonitorFilters
import gs.environment.inject
import gs.presentation.Spacing
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.channels.ReceiveChannel
import kotlinx.coroutines.experimental.channels.consumeEach
import kotlinx.coroutines.experimental.launch
import org.blokada.R

class AFilterListView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    private val ui by lazy { context.inject().instance<UiState>() }
    private val cmd by lazy { context.inject().instance<Commands>() }
    private val f by lazy { context.inject().instance<Filters>() }
    private var allFilters = setOf<Filter>()
    private var filters = listOf<Filter>()
    private var openChannel: ReceiveChannel<Set<Filter>>? = null

    var landscape: Boolean = false
        set(value) {
            field = value
            layoutManager = StaggeredGridLayoutManager(
                    if (value) 2 else 1,
                    StaggeredGridLayoutManager.VERTICAL
            )
        }

    var whitelist: Boolean = false
        set(value) {
            field = value
            refreshFilters()
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        addItemDecoration(Spacing(context))
        setAdapter(adapter)
        landscape = false

        if (openChannel == null) {
            openChannel = cmd.channel(MonitorFilters())
            launch {
                openChannel?.consumeEach { launch(UI) { setFilters(it) }}
            }
        }

        ui.showSystemApps.doOnUiWhenChanged().then {
            refreshFilters()
        }
    }

    private fun setFilters(filter: Set<Filter>) {
        allFilters = filter
        refreshFilters()
    }

    private fun refreshFilters() {
        if (whitelist) {
            Log.v("blokada", "systemapps: ${ui.showSystemApps()}")
            filters = allFilters.filter {
                it.whitelist == true && it.hidden == false
                        && (ui.showSystemApps()
                        || !(f.apps().firstOrNull { app -> app.appId == it.source.source }?.system ?: false))
            }
        } else {
            filters = allFilters.filter { !it.whitelist && !it.hidden }.toList().sortedBy { it.priority }
        }
        adapter.notifyDataSetChanged()
    }

    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.Switch) }

    private val adapter = object : RecyclerView.Adapter<AFilterViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AFilterViewHolder {
            val v = LayoutInflater.from(themedContext).inflate(R.layout.view_filter, parent, false) as AFilterView
            return AFilterViewHolder(v)
        }

        override fun onBindViewHolder(holder: AFilterViewHolder, position: Int) {
            val v = holder.view
            val i = filters[position]
            if (v.tag == null) {
                v.tag = AFilterActor(i, v)
            } else {
                (v.tag as AFilterActor).filter = i
            }
        }

        override fun getItemCount(): Int {
            return filters.size
        }
    }
}

data class AFilterViewHolder(val view: AFilterView): RecyclerView.ViewHolder(view)
