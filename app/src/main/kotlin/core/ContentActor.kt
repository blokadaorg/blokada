package core

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.FrameLayout
import io.codetail.animation.ViewAnimationUtils
import io.codetail.widget.RevealFrameLayout

private data class OpenDash(val d: Dash, val x: Int, val y: Int)

class ContentActor(
        private val ui: UiState,
        private val reveal: RevealFrameLayout,
        private val revealContainer: FrameLayout,
        private val topBar: ATopBarView,
        private val radiusSize: Float
) {

    val onDashOpen = mutableListOf<(Dash?) -> Unit>()

    private val dashesCaches: MutableMap<String, Any?> = mutableMapOf()
    private var openDash: OpenDash? = null

    fun reveal(dash: Dash, x: Int, y: Int, after: () -> Unit = {}) {
        if (openDash?.d == dash) return
        openDash = OpenDash(dash, x, y)

        val view = dashesCaches.get(dash.id)
        if (view is View) {
            revealContainer.addView(view)
        } else if (dash.isSwitch) {
            dash.checked = !dash.checked
            after()
            return
        } else if (!dash.hasView) {
            ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, dash.description)
            after()
            return
        }

        topBar.bg = dash.topBarColor
        topBar.mode = ATopBarView.Mode.BACK
        reveal.visibility = android.view.View.VISIBLE

        val animator = ViewAnimationUtils.createCircularReveal(
                revealContainer, getWidth(x), y, 0f, radiusSize)
        animator.interpolator = AccelerateDecelerateInterpolator()
        animator.duration = 300
        animator.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator?) {
                var v = view
                if (v == null) {
                    v = dash.createView(reveal)
                    if (v is View) {
                        dashesCaches.put(dash.id, v)
                        revealContainer.addView(v)
                    }
                }

                onDashOpen.forEach { it(dash) }
                dash.onDashOpen()
                after()
            }
        })
        animator.start()
    }

    fun back(after: () -> Unit = {}): Boolean {
        topBar.bg = null
        topBar.mode = ATopBarView.Mode.BAR

        if (openDash == null) {
            after()
            return false
        }

        val (dash, x, y) = openDash!!
        val animator = ViewAnimationUtils.createCircularReveal(
                revealContainer, getWidth(x), y, radiusSize, 0f)
        animator.interpolator = AccelerateDecelerateInterpolator()
        animator.duration = 300
        animator.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator?) {
                openDash = null
                revealContainer.removeAllViews()
                reveal.visibility = View.GONE
                after()
            }
        })
        animator.start()
        dash.onBack()
        onDashOpen.forEach { it(null) }
        return true
    }

    private fun getWidth(x: Int): Int {
        return if (x == X_END) topBar.measuredWidth
        else x
    }

    companion object {
        val X_END = -1
    }
}
