package core

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.viewpager.widget.PagerAdapter
import androidx.viewpager.widget.ViewPager
import com.github.salomonbrys.kodein.instance
import gs.presentation.ViewBinder
import gs.presentation.ViewBinderHolder

class VBPagesView(
        ctx: Context,
        attributeSet: AttributeSet
) : ViewPager(ctx, attributeSet) {
    var lock = false

    val ktx = ctx.ktx("VBPagesView")
    val viewBinderHolder: ViewBinderHolder = ktx.di().instance()

    private val dashAdapter = object : PagerAdapter() {
        override fun instantiateItem(container: ViewGroup, position: Int): Any {
            val dash = pages[position]
            val view = dash.createView(context, container)
            view.tag = dash
            dash.attach(view)
            viewBinderHolder.add(dash, view)
            container.addView(view)
            return view
        }

        override fun destroyItem(container: ViewGroup, position: Int, view: Any) {
            container.removeView(view as View)
            val dash = view.tag
            if (dash is ViewBinder) {
                dash.detach(view)
                viewBinderHolder.remove(dash)
            }
        }

        override fun isViewFromObject(view: View, obj: Any) = view == obj
        override fun getCount() = pages.size
    }

    // Used to make ViewPager clear views when its not used
    private val emptyAdapter = object : PagerAdapter() {
        override fun isViewFromObject(view: View, `object`: Any) = true
        override fun getCount() = 0
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        return if (lock)
            true
        else {
            super.dispatchTouchEvent(ev)
        }
    }

    var useSpacer = false

    var pages: List<ViewBinder> = emptyList()
        set(value) {
            field = if (useSpacer) value.map { PageSpacerVB(it) } else value
//            if (value.isEmpty()) adapter = emptyAdapter
//            else if (adapter == emptyAdapter) adapter = dashAdapter
//            else {
//                adapter?.notifyDataSetChanged()
//            }
            adapter = if(value.isEmpty()) emptyAdapter else dashAdapter
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
