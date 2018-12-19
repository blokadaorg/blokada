package gs.presentation

import android.content.Context
import android.support.v7.widget.RecyclerView
import android.support.v7.widget.StaggeredGridLayoutManager

class DashGridView(
        ctx: android.content.Context,
        attributeSet: android.util.AttributeSet
) : android.support.v7.widget.RecyclerView(ctx, attributeSet) {

    val adapter = DashAdapter(context)

    var onScrollToTop = { isTop: Boolean -> }
    private var isTop = true

    var landscape: Boolean = false
        set(value) {
            field = value
            layoutManager = android.support.v7.widget.StaggeredGridLayoutManager(
                    if (value) 3 else 2,
                    StaggeredGridLayoutManager.VERTICAL
            )
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setAdapter(adapter)
        addItemDecoration(Spacing(context, top = 24, left = 2, right = 2))
        setItemViewCacheSize(0)
        landscape = false
        addOnScrollListener(object : android.support.v7.widget.RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: android.support.v7.widget.RecyclerView, newState: Int) { when {
                scrollState != SCROLL_STATE_IDLE -> Unit
                !canScrollVertically(-1) && !isTop -> {
                    isTop = true
                    onScrollToTop(true)
                }
                canScrollVertically(-1) && isTop -> {
                    isTop = false
                    onScrollToTop(false)
                }
            }}
        })
    }


}

class DashAdapter(val ctx: Context) : RecyclerView.Adapter<DashViewHolder>() {

    var items = listOf<ViewBinder>()
        set(value) {
            field = value
            viewTypes = value.map { it to it::class.java.hashCode() }.toMap()
            dashes = value.map { it::class.java.hashCode() to it }.toMap()
            notifyDataSetChanged()
        }

    private var viewTypes = mapOf<ViewBinder, Int>()
    private var dashes = mapOf<Int, ViewBinder>()

    override fun getItemViewType(position: Int): Int {
        val d = items[position]
        return viewTypes.filter { it.key == d }.values.first()
    }

    override fun onCreateViewHolder(parent: android.view.ViewGroup, viewType: Int): DashViewHolder {
        val dash = dashes[viewType]!!
        val v = dash.createView(ctx, parent)
        return DashViewHolder(v)
    }

    override fun onBindViewHolder(holder: DashViewHolder, position: Int) {
        val d = items[position]
        val v = holder.view
        d.attach(v)
    }

    override fun getItemCount(): Int {
        return items.size
    }
}

class DashViewHolder(val view: android.view.View) : android.support.v7.widget.RecyclerView.ViewHolder(view)
