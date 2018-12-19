package filter

import android.content.Context
import android.os.Handler
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
import core.ktx
import gs.environment.inject
import gs.presentation.Spacing
import org.blokada.R
import tunnel.Filter
import tunnel.prioritised

class AFilterListView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    private val ui by lazy { context.inject().instance<UiState>() }
    private val f by lazy { context.inject().instance<Filters>() }
    private var allFilters = setOf<Filter>()
    private var filters = listOf<Filter>()

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

    var onItemClick = { x: Int, y: Int, filter: Filter? -> }

    private var switchEnabled = true
    private val switchHandler = Handler {
        switchEnabled = true
        adapter.notifyDataSetChanged()
        true
    }


    override fun onFinishInflate() {
        super.onFinishInflate()
        addItemDecoration(Spacing(context))
        setAdapter(adapter)
        landscape = false

        val switchInactive = {
            switchHandler.removeMessages(0)
            switchHandler.sendEmptyMessageDelayed(0, 5000)
            switchEnabled = false
            adapter.notifyDataSetChanged()
            Unit
        }

        val switchActive = { _: Pair<Int, Int> ->
            switchHandler.removeMessages(0)
            switchEnabled = true
            adapter.notifyDataSetChanged()
            Unit
        }

        context.ktx().cancel(tunnel.Events.FILTERS_CHANGING, switchInactive)
        context.ktx().on(tunnel.Events.FILTERS_CHANGING, switchInactive)

        context.ktx().cancel(tunnel.Events.RULESET_BUILT, switchActive)
        context.ktx().on(tunnel.Events.RULESET_BUILT, switchActive)

        val updateFilters = { it: Collection<Filter> ->
            setFilters(it.toSet())
        }

        context.ktx().cancel(tunnel.Events.FILTERS_CHANGED, updateFilters)
        context.ktx().on(tunnel.Events.FILTERS_CHANGED, updateFilters)

        ui.showSystemApps.doOnUiWhenChanged().then {
            refreshFilters()
        }
    }

    private fun setFilters(filter: Set<Filter>) {
        allFilters = filter
        refreshFilters()
    }

    private fun refreshFilters() {
        filters = if (whitelist) {
            Log.v("blokada", "systemapps: ${ui.showSystemApps()}")
            allFilters.filter {
                it.whitelist == true && it.hidden == false
                        && (ui.showSystemApps()
                        || !(f.apps().firstOrNull { app -> app.appId == it.source.source }?.system ?: false))
            }
        } else {
            allFilters.filter { !it.whitelist && !it.hidden }
        }.toList().prioritised()
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
                v.tag = AFilterActor(i, switchEnabled, v)
            } else {
                (v.tag as AFilterActor).switchEnabled = switchEnabled
                (v.tag as AFilterActor).filter = i
            }

            v.setOnClickListener {
                onItemClick((v.x + v.width / 2).toInt(), (v.y + v.height / 2).toInt(), i)
            }
        }

        override fun getItemCount(): Int {
            return filters.size
        }
    }
}

data class AFilterViewHolder(val view: AFilterView): RecyclerView.ViewHolder(view)
