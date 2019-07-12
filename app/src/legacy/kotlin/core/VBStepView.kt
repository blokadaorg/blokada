package core

import android.content.Context
import android.os.Handler
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.viewpager.widget.ViewPager
import gs.presentation.ViewBinder
import org.blokada.R

class VBStepView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    var onItemRemove = { item: ViewBinder -> }

    init {
        inflate(context, R.layout.vbstepview_content, this)
    }

    private val pagesView = findViewById<VBPagesView>(R.id.pages)
    private val dotsView = findViewById<DotsView>(R.id.dots)
    private val containerView = findViewById<ConstraintLayout>(R.id.container)

    private val pageChanged = object : ViewPager.SimpleOnPageChangeListener() {
        override fun onPageSelected(position: Int) {
            dotsView.section = "Step ${position + 1}"
            val page = pages[position]
            if (page is Stepable) page.focus()
        }
    }

    init {
        dotsView.viewPager = pagesView
        dotsView.section = "Step 1"
        dotsView.sleeping = true
        pagesView.addOnPageChangeListener(pageChanged)
        pagesView.useSpacer = true
    }

    var pages: List<ViewBinder> = emptyList()
        set(value) {
            field = value
            pagesView.pages = pages
            dotsView.viewPager = pagesView
            dotsView.visibility = if (value.size == 1) View.GONE else View.VISIBLE
            pagesView.currentItem = 0
            value.firstOrNull()?.apply {
                if (this is Stepable) {
                    val msg = focusHandler.obtainMessage(0)
                    msg.obj = this
                    focusHandler.sendMessageDelayed(msg, 500)
                }
            }
        }

    fun next() {
        val current = pagesView.currentItem
        if (current < pages.size - 1) pagesView.currentItem = current + 1
    }

    private val focusHandler = Handler {
        val page = it.obj as Stepable
        page.apply { focus() }
        true
    }
}
