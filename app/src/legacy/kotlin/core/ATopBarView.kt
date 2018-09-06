package core

import android.animation.ArgbEvaluator
import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.drawable.ColorDrawable
import android.util.AttributeSet
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.ImageView
import android.widget.RelativeLayout
import gs.presentation.ResizeAnimation
import gs.presentation.doAfter
import gs.presentation.toPx
import org.blokada.R

class ATopBarView(
        ctx: Context,
        attributeSet: AttributeSet
) : RelativeLayout(ctx, attributeSet) {

    enum class Mode { WELCOME, BAR, BACK }

    var mode = Mode.WELCOME
        set(value) {
            when {
                field == value -> Unit
                value == Mode.WELCOME -> toWelcome { field = value; onModeSwitched() }
                value == Mode.BACK -> toBack { field = value; onModeSwitched() }
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

    val action1 by lazy { findViewById(R.id.topbar_action1) as ADashView }
    val action2 by lazy { findViewById(R.id.topbar_action2) as ADashView }
    val action3 by lazy { findViewById(R.id.topbar_action3) as ADashView }
    val action4 by lazy { findViewById(R.id.topbar_action4) as ADashView }

    private val actions by lazy { listOf(action1, action2, action3, action4) }
    private val logo by lazy { findViewById(R.id.topbar_logo) as ImageView }
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
        mode = Mode.WELCOME
    }

    private fun rotate(view: View, how: Float, after: () -> Unit) {
        view.animate().rotationBy(how).setInterpolator(inter).setDuration(80).doAfter(after)
    }

    private val inter = AccelerateDecelerateInterpolator()

    private var halfWidthPx = 0
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (halfWidthPx == w / 2) return
        halfWidthPx = w / 2
        if (mode == Mode.WELCOME) toWelcome {}
    }

    private fun toWelcome(after: () -> Unit) {
        logo.visibility = View.VISIBLE
        val a = ResizeAnimation(logo, resources.toPx(196), logo.measuredHeight, square = true)
        a.duration = 300
        a.interpolator = DecelerateInterpolator(1.3f)
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(halfWidthPx - resources.toPx(98 + 8).toFloat())

        header.animate().translationX(100f).alpha(0f).doAfter {
            header.visibility = View.GONE
        }

        back.animate().setDuration(dur).translationX(-180f)

        actions.forEach { action ->
            action.animate().translationX(50f).alpha(0f)
        }

        if (mode != Mode.WELCOME) toBackground(color = null)
        after()
    }

    private fun toBar(after: () -> Unit) {
        logo.visibility = View.VISIBLE
        val a = ResizeAnimation(logo, resources.toPx(64), logo.measuredHeight, square = true)
        a.duration = 300
        a.interpolator = DecelerateInterpolator()
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(0f)

        header.visibility = View.VISIBLE
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
        a.interpolator = DecelerateInterpolator()
        logo.startAnimation(a)
        logo.animate().setDuration(dur).translationX(-240f).doAfter {
            logo.visibility = View.GONE
        }

        header.visibility = View.VISIBLE
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
        val colorFrom = (background as ColorDrawable).color
        var colorTo = color ?: R.color.colorBackground
        colorTo = resources.getColor(colorTo)

        val animator = getAnimator(colorFrom, colorTo)
        animator.duration = 200
        animator.start()
        after()
    }

    private fun getAnimator(colorFrom: Int, colorTo: Int): ObjectAnimator {
        return ObjectAnimator.ofObject(this,
                "backgroundColor",
                ArgbEvaluator(),
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
