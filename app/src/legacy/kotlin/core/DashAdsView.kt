package core

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.AbsListView
import android.widget.FrameLayout
import androidx.recyclerview.widget.RecyclerView
import filter.AFilterListView
import io.codetail.widget.RevealFrameLayout
import org.blokada.R

class DashAdsView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet), Backable, Scrollable {

    private val listView by lazy { findViewById<AFilterListView>(R.id.list) }
    private val revealView by lazy { findViewById<RevealFrameLayout>(R.id.reveal) }
    private val revealContainerView by lazy { findViewById<FrameLayout>(R.id.reveal_container) }

    private var openClickCoordinates: Pair<Int, Int>? = null

    var small: String? = null
        set(value) {
            field = value
            if (value != null) {
//                smallView.visibility = View.VISIBLE
//                smallView.text = value
            } else {
//                smallView.visibility = View.GONE
            }
        }

    override fun onFinishInflate() {
        super.onFinishInflate()

        listView.onItemClick = { x: Int, y: Int, f: tunnel.Filter? ->
            openClickCoordinates = x to y
            val radiusSize = height.toFloat()
            revealView.visibility = android.view.View.VISIBLE
            val animator = io.codetail.animation.ViewAnimationUtils.createCircularReveal(
                    revealContainerView, x, y, 0f, radiusSize)
            animator.interpolator = android.view.animation.AccelerateDecelerateInterpolator()
            animator.duration = 300
            animator.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator?) {
                    val dash = filter.EditFilterDash(f)
                    val view = dash.createView(revealContainerView.context, revealContainerView)
                    dash.attach(view)
                    revealContainerView.addView(view)
                }
            })
            animator.start()
        }
    }

    override fun handleBackPressed(): Boolean {
        openClickCoordinates?.apply {
            val animator = io.codetail.animation.ViewAnimationUtils.createCircularReveal(
                    revealContainerView, first, second, height.toFloat(), 0f)
            animator.interpolator = android.view.animation.AccelerateDecelerateInterpolator()
            animator.duration = 300
            animator.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator?) {
                    revealView.visibility = android.view.View.GONE
                    revealContainerView.removeAllViews()
                }
            })
            animator.start()
            return true
        }
        openClickCoordinates = null
        return false
    }

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) {
        listView.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
//                if (dy > 0) {
//                    onScrollUp()
//                } else if (dy < 0) {
//                    onScrollDown()
//                }
            }

            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                when (newState) {
                    AbsListView.OnScrollListener.SCROLL_STATE_TOUCH_SCROLL -> onScrollDown()
                    AbsListView.OnScrollListener.SCROLL_STATE_IDLE -> onScrollUp()
                }
            }
        })
    }

    override fun getScrollableView() = listView
}


interface Backable {
    fun handleBackPressed(): Boolean
}

interface ListSection {
    fun setOnSelected(listener: (item: Navigable?) -> Unit)
    fun scrollToSelected()
    fun selectNext() {}
    fun selectPrevious() {}
    fun unselect() {}
}

interface Scrollable {
    fun setOnScroll(
            onScrollDown: () -> Unit = {},
            onScrollUp: () -> Unit = {},
            onScrollStopped: () -> Unit = {}
    )
    fun getScrollableView(): View
}

interface Stepable {
    fun focus()
}

interface Navigable {
    fun up()
    fun down()
    fun left()
    fun right()
    fun enter()
    fun exit()
}
