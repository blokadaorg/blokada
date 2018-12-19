package core

import android.content.Context
import android.support.v4.view.PagerAdapter
import android.support.v4.view.ViewPager
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import gs.presentation.ViewBinder

class VBPagesView(
        ctx: Context,
        attributeSet: AttributeSet
) : ViewPager(ctx, attributeSet) {

    private val dashAdapter = object : PagerAdapter() {
        override fun instantiateItem(container: ViewGroup, position: Int): Any {
            val dash = pages[position]
            val view = dash.createView(context, container)
            view.tag = dash
            dash.attach(view)
            container.addView(view)
            return view
        }

        override fun destroyItem(container: ViewGroup, position: Int, view: Any) {
            container.removeView(view as View)
            val dash = view.tag
            if (dash is ViewBinder) dash.detach(view)
        }

        override fun isViewFromObject(view: View, obj: Any) = view == obj
        override fun getCount() = pages.size
    }

    var useSpacer = false

    var pages: List<ViewBinder> = emptyList()
        set(value) {
            field = if (useSpacer) value.map { PageSpacerVB(it) } else value
            adapter = dashAdapter
        }

}

class PageSpacerVB(private val delegate: ViewBinder) : ViewBinder {

    override fun createView(ctx: Context, parent: ViewGroup): View {
        val frame = LinearLayout(ctx)
        val margin = ctx.dpToPx(16)
        frame.setPadding(margin, margin, margin, margin)

        val child = delegate.createView(ctx, frame)
        frame.addView(child)
        return frame
    }

    override fun attach(view: View) {
        view as LinearLayout
        delegate.attach(view.getChildAt(0))
    }

    override fun detach(view: View) {
        view as LinearLayout
        delegate.detach(view.getChildAt(0))
    }

    override val viewType = delegate.viewType

}
