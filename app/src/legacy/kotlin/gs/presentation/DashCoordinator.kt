package gs.presentation

import android.view.View

private data class OpenDash(val d: ViewBinder, val x: Int, val y: Int)

class DashCoordinator(
        private val reveal: io.codetail.widget.RevealFrameLayout,
        private val revealContainer: android.widget.FrameLayout,
        private val topBar: TopBar,
        private val radiusSize: Float
) {

    val onDashOpen = mutableListOf<(ViewBinder?) -> Unit>()

    private val dashesCaches: MutableMap<ViewBinder, View?> = mutableMapOf()
    private var openDash: gs.presentation.OpenDash? = null

    fun reveal(dash: ViewBinder, x: Int, y: Int, after: () -> Unit = {}) {
        if (openDash?.d == dash) return
        openDash = gs.presentation.OpenDash(dash, x, y)

        val view = dashesCaches[dash]
        if (view is View) {
            revealContainer.addView(view)
        }

//        topBar.bg = dash.topBarColor
        topBar.v.mode = TopBarView.Mode.BACK
        topBar.dash1 = null
        topBar.dash2 = null
        topBar.dash3 = null
        reveal.visibility = android.view.View.VISIBLE

        val animator = io.codetail.animation.ViewAnimationUtils.createCircularReveal(
                revealContainer, getWidth(x), getHeight(y), 0f, radiusSize)
        animator.interpolator = android.view.animation.AccelerateDecelerateInterpolator()
        animator.duration = 300
        animator.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator?) {
                var v = view
                if (v == null) {
                    v = dash.createView(reveal.context, reveal)
                    revealContainer.addView(v)
                    dashesCaches.put(dash, v)
                }

                onDashOpen.forEach { it(dash) }
                dash.attach(v)
                after()
            }
        })
        animator.start()
    }

    fun back(after: () -> Unit = {}): Boolean {
        topBar.v.bg = null
        topBar.v.mode = TopBarView.Mode.BAR
        topBar.dash1 = null
        topBar.dash2 = null
        topBar.dash3 = null

        if (openDash == null) {
            after()
            return false
        }

        val (dash, x, y) = openDash!!
        val animator = io.codetail.animation.ViewAnimationUtils.createCircularReveal(
                revealContainer, getWidth(x), getHeight(y), radiusSize, 0f)
        animator.interpolator = android.view.animation.AccelerateDecelerateInterpolator()
        animator.duration = 300
        animator.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator?) {
                openDash = null
                revealContainer.removeAllViews()
                reveal.visibility = android.view.View.GONE
                after()
            }
        })
        animator.start()
        try { dash.detach(revealContainer.getChildAt(0)) } catch (e: Exception) {}
        onDashOpen.forEach { it(null) }
        return true
    }

    private fun getWidth(x: Int): Int {
        return if (x == gs.presentation.DashCoordinator.Companion.X_END) topBar.v.measuredWidth
        else if (x == gs.presentation.DashCoordinator.Companion.X_HALF) topBar.v.measuredWidth / 2
        else x
    }

    private fun getHeight(y: Int): Int {
        return if (y == gs.presentation.DashCoordinator.Companion.Y_END) revealContainer.measuredHeight
        else y
    }

    companion object {
        val X_END = -1
        val X_HALF = -2
        val Y_END = -3
    }
}
