package gs.presentation

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import core.*
import org.blokada.R
import java.lang.ref.WeakReference

/**
 * Represents basic view binding structure that can be embedded in lists or displayed independently,
 * also as a widget.
 */
interface ViewBinder {
    fun createView(ctx: Context, parent: ViewGroup): View
    fun attach(view: View)
    fun detach(view: View)

    val viewType: Int
}

interface CallbackViewBinder : ViewBinder {
    fun onAttached(attached: () -> Unit)
    fun onDetached(detached: () -> Unit)
}

interface NamedViewBinder : ViewBinder {
    val name: Resource
}

class ViewBinderHolder {
    private val binders = mutableListOf<Pair<ViewBinder, WeakReference<View>>>()

    fun add(binder: ViewBinder, view: View) {
        if (binders.firstOrNull { it.first == binder } == null) {
            binders.add(binder to WeakReference(view))
        }
    }

    fun remove(binder: ViewBinder) {
        binders.firstOrNull { it.first == binder }?.run {
            binders.remove(this)
        }
    }

    fun attach() {
        binders.forEach {
            it.second.get()?.run {
                it.first.attach(this)
            }
        }
    }

    fun detach() {
        binders.forEach {
            it.second.get()?.run {
                it.first.detach(this)
            }
        }
    }

}

open class LayoutViewBinder(
        private val resId: Int
) : ViewBinder {

    override fun createView(ctx: Context, parent: ViewGroup): View {
        return LayoutInflater.from(ctx).inflate(resId, parent, false)
    }

    override fun attach(view: View) = Unit
    override fun detach(view: View) = Unit
    override val viewType = ViewTypeGenerator.get(this, resId)
}

abstract class ListViewBinder : LayoutViewBinder(R.layout.vblistview), ListSection, Scrollable {

    abstract fun attach(view: VBListView)
    open fun detach(view: VBListView) = Unit

    final override fun attach(view: View) {
        view as VBListView
        this.view = view
        view.setOnSelected(onSelectedListener)
        attach(view)
    }

    final override fun detach(view: View) {
        view as VBListView
        view.unselect()
        this.view = null
        detach(view)
    }

    protected var view: VBListView? = null
    protected var onSelectedListener: (Navigable?) -> Unit = {}

    override fun setOnSelected(listener: (item: Navigable?) -> Unit) {
        this.onSelectedListener = listener
        view?.setOnSelected(listener)
    }

    override fun scrollToSelected() {
        view?.scrollToSelected()
    }

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) = Unit

    override fun getScrollableView() = view!!

    override fun selectNext() { view?.selectNext() }
    override fun selectPrevious() { view?.selectPrevious() }
    override fun unselect() { view?.unselect() }

}

object ViewTypeGenerator {
    fun get(instance: Any, payload: Any? = null) = when {
        payload == null -> instance.hashCode()
        else -> instance.javaClass.hashCode() + payload.hashCode()
    }
}


