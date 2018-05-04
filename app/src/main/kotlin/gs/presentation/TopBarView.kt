package gs.presentation

import android.view.View
import gs.kar.R

class TopBarView(
        ctx: android.content.Context,
        attributeSet: android.util.AttributeSet
) : android.widget.RelativeLayout(ctx, attributeSet) {

    enum class Mode { WELCOME, BAR, BACK }

    var mode = gs.presentation.TopBarView.Mode.WELCOME
        set(value) {
            when {
                field == value -> Unit
                value == gs.presentation.TopBarView.Mode.WELCOME -> toWelcome { field = value; onModeSwitched() }
                value == gs.presentation.TopBarView.Mode.BACK -> toBack { field = value; onModeSwitched() }
                else -> toBar { field = value; onModeSwitched() }
            }
        }

    var active = false
        set(value) {
            when {
                field == value -> Unit
                value == true -> toActive { field = value }
                else -> fromActive { field = value }
            }
        }

    var waiting = false
        set(value) {
            when {
                field == value -> Unit
                value == true -> toWaiting { field = value }
                else -> fromWaiting { field = value }
            }
        }

    var bg: Int? = null

    var onLogoClick = {}
    var onBackClick = {}
    var onModeSwitched = {}

    val action1 by lazy { findViewById(R.id.topbar_action1) as IconDashView }
    val action2 by lazy { findViewById(R.id.topbar_action2) as IconDashView }
    val action3 by lazy { findViewById(R.id.topbar_action3) as IconDashView }
    val action4 by lazy { findViewById(R.id.topbar_action4) as IconDashView }

    private val actions by lazy { listOf(action1, action2, action3, action4) }
    val logo by lazy { findViewById(R.id.topbar_logo) as android.widget.ImageView }
    private val back by lazy { findViewById(R.id.topbar_back) as View }

    private val header by lazy { findViewById(R.id.topbar_header) as View }

    private val dur = 200L

    override fun onFinishInflate() {
        super.onFinishInflate()

        logo.setOnClickListener {
            rotate(logo, -5f, {
                rotate(logo, 10f, {
                    rotate(logo, -5f, {
                        onLogoClick()
                    })
                })
            })
        }

        back.setOnClickListener {
            rotate(back, -15f, {
                rotate(back, 30f, {
                    rotate(back, -15f, {
                        onBackClick()
                    })
                })
            })
        }

        fromActive {}
        back.translationX = -180f
        mode = Mode.BAR
    }

    private fun rotate(view: android.view.View, how: Float, after: () -> Unit) {
        view.animate().rotationBy(how).setInterpolator(inter).setDuration(80).doAfter(after)
    }

    private val inter = android.view.animation.AccelerateDecelerateInterpolator()

    private var halfWidthPx = 0
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (halfWidthPx == w / 2) return
        halfWidthPx = w / 2
        if (mode == gs.presentation.TopBarView.Mode.WELCOME) toWelcome {}
    }

    private fun toWelcome(after: () -> Unit) {
        logo.visibility = android.view.View.VISIBLE
        val a = ResizeAnimation(logo, resources.toPx(196), logo.measuredHeight, square = true)
        a.duration = 300
        a.interpolator = android.view.animation.DecelerateInterpolator(1.3f)
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(halfWidthPx - resources.toPx(98 + 8).toFloat())

        header.animate().translationX(100f).alpha(0f).doAfter {
            header.visibility = android.view.View.GONE
        }

        back.animate().setDuration(dur).translationX(-180f)

        actions.forEach { action ->
            action.animate().translationX(50f).alpha(0f)
        }

        if (mode != gs.presentation.TopBarView.Mode.WELCOME) toBackground(color = null)
        after()
    }

    private fun toBar(after: () -> Unit) {
        logo.visibility = android.view.View.VISIBLE
        val a = ResizeAnimation(logo, resources.toPx(64), logo.measuredHeight, square = true)
        a.duration = 300
        a.interpolator = android.view.animation.DecelerateInterpolator()
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(0f)

        header.visibility = android.view.View.VISIBLE
        header.animate().translationX(0f).alpha(1f)

        back.animate().setDuration(dur).translationX(-180f)

        actions.forEach { action ->
            action.animate().translationX(0f).alpha(1f)
        }

        toBackground(color = bg ?: R.color.colorBackgroundLight)
        after()
    }

    private fun toBack(after: () -> Unit) {
        val a = ResizeAnimation(logo, resources.toPx(64), logo.measuredHeight, square = true)
        a.duration = 300
        a.interpolator = android.view.animation.DecelerateInterpolator()
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(-240f).doAfter {
            logo.visibility = android.view.View.GONE
        }

        header.visibility = android.view.View.VISIBLE
        header.animate().translationX(0f).alpha(1f)

        back.animate().setDuration(dur).translationX(0f)

        actions.forEach { action ->
            action.animate().translationX(0f).alpha(1f)
        }

        toBackground(color = bg ?: R.color.colorBackgroundLight)
        after()
    }

    private fun toActive(after: () -> Unit) {
        logo.setColorFilter(color(active = true, waiting = waiting))
        after()
    }

    private fun fromActive(after: () -> Unit) {
        logo.setColorFilter(color(active = false, waiting = waiting))
        after()
    }

    private fun toWaiting(after: () -> Unit) {
        logo.setColorFilter(color(active = active, waiting = true))
        logo.isEnabled = false
        after()
    }

    private fun fromWaiting(after: () -> Unit) {
        logo.setColorFilter(color(active = active, waiting = false))
        logo.isEnabled = true
        after()
    }

    private fun toBackground(color: Int?, after: () -> Unit = {}) {
        val colorFrom = (background as android.graphics.drawable.ColorDrawable).color
        var colorTo = color ?: R.color.colorBackground
        colorTo = resources.getColor(colorTo)

        val animator = getAnimator(colorFrom, colorTo)
        animator.duration = 200
        animator.start()
        after()
    }

    private fun getAnimator(colorFrom: Int, colorTo: Int): android.animation.ObjectAnimator {
        return android.animation.ObjectAnimator.ofObject(this,
                "backgroundColor",
                android.animation.ArgbEvaluator(),
                colorFrom,
                colorTo)
    }

    private fun color(active: Boolean, waiting: Boolean): Int {
        return when {
            waiting -> resources.getColor(R.color.colorLogoWaiting)
            active -> resources.getColor(android.R.color.transparent)
            else -> resources.getColor(R.color.colorLogoInactive)
        }
    }
}
