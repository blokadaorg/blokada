package core

import android.content.Context
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Handler
import android.support.constraint.ConstraintLayout
import android.support.v7.widget.LinearLayoutManager
import android.support.v7.widget.RecyclerView
import android.support.v7.widget.helper.ItemTouchHelper
import android.util.AttributeSet
import android.view.KeyEvent
import android.view.View
import android.view.View.OnKeyListener
import android.view.ViewGroup
import android.widget.FrameLayout
import gs.presentation.ViewBinder
import org.blokada.R



class VBListView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet), Scrollable, ListSection {

    override fun setOnSelected(listener: (item: SlotVB?) -> Unit) {
        onItemSelect = listener
        if (adapter.selectedItem != -1) listener(items[adapter.selectedItem] as SlotVB)
    }

    var onItemRemove = { item: ViewBinder -> }
    var onEndReached = { }
    private var onItemSelect = { item: SlotVB? -> }

    init {
        inflate(context, R.layout.vblistview_content, this)
    }

    private val listView = findViewById<RecyclerView>(R.id.list)
    private val containerView = findViewById<ConstraintLayout>(R.id.container)
    private var layoutManager = LinearLayoutManager(context)
    private var alternativeMode = false

    init {
        listView.addItemDecoration(VerticalSpace(context.dpToPx(6)))
        listView.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)

                if (!recyclerView.canScrollVertically(1)) {
                    onEndReached()
                }
            }
        })
    }

    override fun selectNext() {
        adapter.tryMoveSelection(1)
    }

    override fun selectPrevious() {
        adapter.tryMoveSelection(-1)
    }

    override fun unselect() {
        val old = adapter.selectedItem
        if (old != -1) {
            adapter.selectedItem = -1
            adapter.notifyItemChanged(old)
            onItemSelect(null)
        }
    }

    private val scroll = Handler {
        if (adapter.selectedItem != -1) listView.smoothScrollToPosition(adapter.selectedItem)
        true
    }

    override fun scrollToSelected() {
        if (alternativeMode) {
            val lastVisible = layoutManager.findLastCompletelyVisibleItemPosition()
            if (adapter.selectedItem >= lastVisible - 1)
                listView.smoothScrollBy(0, 200)
        } else {
            val firstVisible = layoutManager.findFirstCompletelyVisibleItemPosition()
            if (adapter.selectedItem <= firstVisible + 1)
                listView.smoothScrollBy(0, -200)
        }
        handlerek.sendEmptyMessageDelayed(0, 800)
    }

    val handlerek = Handler {
        listView.smoothScrollToPosition(adapter.selectedItem)
//        val firstVisible = layoutManager.findFirstCompletelyVisibleItemPosition()
//        if (adapter.selectedItem <= firstVisible + 1)
//            listView.smoothScrollBy(0, -200)
        true
    }

    private val adapter = object : RecyclerView.Adapter<ListerViewHolder>() {

        var selectedItem = -1

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ListerViewHolder {
            val creator = viewCreators[viewType]!!
            val view = creator.createView(context, parent)
            return ListerViewHolder(view, creator)
        }

        override fun onBindViewHolder(holder: ListerViewHolder, position: Int) {
            val oldDash = items[holder.adapterPosition]
            oldDash.detach(holder.view)
            val dash = items[position]
            dash.attach(holder.view)
            if (position == selectedItem) {
                holder.view.setBackgroundResource(R.drawable.bg_focused)
                onItemSelect(dash as SlotVB)
            } else {
                holder.view.background = null
            }
        }

//        override fun onViewRecycled(holder: ListerViewHolder) = holder.creator.detach(holder.view)
        override fun getItemCount() = items.size
        override fun getItemViewType(position: Int) = items[position].viewType

        override fun onAttachedToRecyclerView(recyclerView: RecyclerView) {
            super.onAttachedToRecyclerView(recyclerView)

            recyclerView.setOnKeyListener(OnKeyListener { v, keyCode, event ->
                if (event.action == KeyEvent.ACTION_DOWN) {
                    if (isConfirmButton(event)) {
                        if (event.flags and KeyEvent.FLAG_LONG_PRESS == KeyEvent.FLAG_LONG_PRESS) {
                            recyclerView.getViewHolder(selectedItem)?.itemView?.performLongClick()
                        } else event.startTracking()
                        return@OnKeyListener true
                    } else {
                        if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN) {
                            return@OnKeyListener tryMoveSelection(1)
                        } else if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
                            return@OnKeyListener tryMoveSelection(-1)
                        }
                    }
                } else if (event.action == KeyEvent.ACTION_UP && isConfirmButton(event)
                        && event.flags and KeyEvent.FLAG_LONG_PRESS != KeyEvent.FLAG_LONG_PRESS) {
                    recyclerView.getViewHolder(selectedItem)?.itemView?.performClick()
                    return@OnKeyListener true
                }
                false
            })
        }

        private fun RecyclerView.getViewHolder(position: Int) = if (position == -1) null
            else findViewHolderForAdapterPosition(position)

        fun tryMoveSelection(direction: Int): Boolean {
            val nextSelectItem = selectedItem + direction

            if (nextSelectItem in 0..(itemCount - 1)) {
                notifyItemChanged(selectedItem)
                selectedItem = nextSelectItem
                notifyItemChanged(selectedItem)
                listView.scrollToPosition(selectedItem)
                return true
            }

            return false
        }

        private fun isConfirmButton(event: KeyEvent) = event.keyCode in buttonsEnter

    }

    private val touchHelper = object : ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.END) {
        override fun onMove(p0: RecyclerView, p1: RecyclerView.ViewHolder, p2: RecyclerView.ViewHolder) = false

        override fun onSwiped(holder: RecyclerView.ViewHolder, direction: Int) {
            onItemRemove(items[holder.adapterPosition])
            items.removeAt(holder.adapterPosition)
            adapter.notifyItemRemoved(holder.adapterPosition)
        }

        override fun onChildDraw(c: Canvas, recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder,
                                 dX: Float, dY: Float, actionState: Int, isCurrentlyActive: Boolean) {
            viewHolder.itemView.alpha = 1f - (dX / viewHolder.itemView.width) * 2
            super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive)
        }
    }

    init {
        layoutManager.stackFromEnd = true
        listView.layoutManager = layoutManager
        listView.adapter = adapter
//        ItemTouchHelper(touchHelper).attachToRecyclerView(listView)
    }

    private val viewCreators = mutableMapOf<Int, ViewBinder>()
    private val items = mutableListOf<ViewBinder>()

    private data class ListerViewHolder(
            val view: View,
            val creator: ViewBinder
    ): RecyclerView.ViewHolder(view)

    fun add(item: ViewBinder, position: Int = -1) {
        viewCreators[item.viewType] = item
        if (position == -1) {
            items.add(item)
            adapter.notifyItemInserted(items.size - 1)
        } else {
            val firstWasVisible = layoutManager.findFirstCompletelyVisibleItemPosition() == 0
            items.add(position, item)
            adapter.notifyItemInserted(position)
            if (firstWasVisible) listView.smoothScrollToPosition(0)
        }
//        listView.smoothScrollToPosition(items.size - 1)
    }

    fun remove(item: ViewBinder) {
        val position = items.indexOf(item)
        items.remove(item)
        adapter.notifyItemRemoved(position)
    }

    fun set(items: List<ViewBinder>) {
        this.items.clear()
        this.items.addAll(items)
        items.forEach { viewCreators[it.viewType] = it }
        unselect()
        adapter.notifyDataSetChanged()
//        listView.smoothScrollToPosition(items.size - 1)
    }

    fun enableAlternativeMode() {
        alternativeMode = true
        layoutManager = LinearLayoutManager(context)
        listView.layoutManager = layoutManager

//        val lp = containerView.layoutParams as FrameLayout.LayoutParams
//        lp.marginEnd = 0
//        lp.marginStart = 0
//        containerView.layoutParams = lp
    }

    override fun getScrollableView() = listView

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    class VerticalSpace(val height: Int): RecyclerView.ItemDecoration() {
        override fun getItemOffsets(outRect: Rect, view: View, parent: RecyclerView, state: RecyclerView.State) {
            outRect.top = height
        }
    }
}
