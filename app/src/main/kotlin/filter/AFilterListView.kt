package filter

import android.content.Context
import android.support.v7.widget.RecyclerView
import android.support.v7.widget.StaggeredGridLayoutManager
import android.util.AttributeSet
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import core.Filter
import core.UiState
import gs.environment.inject
import gs.presentation.Spacing
import gs.property.IWhen
import org.blokada.R

class AFilterListView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    private val s by lazy { context.inject().instance<core.Filters>() }
    private val ui by lazy { context.inject().instance<UiState>() }
    private var filters = listOf<Filter>()
    private var listener: IWhen? = null

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

        s.filters.cancel(listener)
        s.filters.doOnUiWhenSet().then { refreshFilters() }
    }

    private fun refreshFilters() {
        if (whitelist) {
            filters = s.filters().filter {
                it.whitelist == true
                        && (ui.showSystemApps()
                        || !((it.source as? FilterSourceApp)?.system ?: false))
            }
        } else {
            filters = s.filters().filter { it.whitelist == false }
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
