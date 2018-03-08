package core

import android.content.Context
import android.support.v7.widget.RecyclerView
import android.support.v7.widget.StaggeredGridLayoutManager
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.ViewGroup
import org.blokada.R
import gs.presentation.Spacing

class AGridView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    var ui: UiState? = null
    var contentActor: ContentActor? = null

    var items = listOf<Dash>()
        set(value) {
            field = value
            adapter.notifyDataSetChanged()
        }

    var onScrollToTop = { isTop: Boolean -> }
    private var isTop = true

    var landscape: Boolean = false
        set(value) {
            field = value
            layoutManager = StaggeredGridLayoutManager(
                    if (value) 3 else 2,
                    StaggeredGridLayoutManager.VERTICAL
            )
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setAdapter(adapter)
        addItemDecoration(Spacing(context, top = 24))
        landscape = false
        addOnScrollListener(object : OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) { when {
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

    private val adapter = object : RecyclerView.Adapter<DashViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): DashViewHolder {
            val v = LayoutInflater.from(context).inflate(R.layout.view_dash, parent, false) as ADashView
            return DashViewHolder(v)
        }

        override fun onBindViewHolder(holder: DashViewHolder, position: Int) {
            val v = holder.view
            val i = items[position]
            if (v.tag == null) {
                v.tag = ADashActor(i, v, ui!!, contentActor!!)
            } else {
                (v.tag as ADashActor).dash = i
            }
        }

        override fun getItemCount(): Int {
            return items.size
        }
    }

}

class DashViewHolder(val view: ADashView) : RecyclerView.ViewHolder(view)
