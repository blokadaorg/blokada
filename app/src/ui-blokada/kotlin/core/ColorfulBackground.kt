package core

import android.animation.ArgbEvaluator
import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import androidx.annotation.ArrayRes
import org.blokada.R
import tunnel.Request


class ColorfulBackground(
        ctx: Context,
        attributeSet: AttributeSet
) : View(ctx, attributeSet), ActiveBackground {

    private val gradientPaint: Paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val evaluator: ArgbEvaluator = ArgbEvaluator()
    private var currentGradient: IntArray = mix(1f,
                positionToGradient(0),
                positionToGradient(0))

    private var on = false

    init {
        initGradient()
    }

    override fun onOpenSection(after: () -> Unit) {
    }

    override fun onCloseSection() {
    }

    private fun initGradient() {
        val centerX = width * 0.5f
        val gradient = LinearGradient(
                centerX, 0f, centerX, height.toFloat(),
                currentGradient, null,
                Shader.TileMode.MIRROR)
        gradientPaint.shader = gradient
    }


    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        initGradient()
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), gradientPaint)
        super.onDraw(canvas)
    }

    override fun onScroll(fraction: Float, oldPosition: Int, newPosition: Int) {
        currentGradient = mix(fraction,
                positionToGradient(oldPosition),
                positionToGradient(newPosition))
        initGradient()
        invalidate()
    }

    override fun onPositionChanged(position: Int) {
    }

    override fun setTunnelState(state: TunnelState) {
        on = state == TunnelState.ACTIVE
    }

    override fun setOnClickSwitch(onClick: () -> Unit) {
    }

    override fun setRecentHistory(items: List<Request>) {
    }

    override fun addToHistory(item: Request) {
    }

    private fun mix(fraction: Float, c1: IntArray, c2: IntArray): IntArray {
        return intArrayOf(evaluator.evaluate(fraction, c1[0], c2[0]) as Int, evaluator.evaluate(fraction, c1[1], c2[1]) as Int)
    }

    private fun positionToGradient(position: Int): IntArray {
        return if (position == 0) colors(R.array.gradient0)
        else when (position - 1 % 4) {
            0 -> colors(R.array.gradient2)
            1 -> colors(R.array.gradient3)
            2 -> colors(R.array.gradient4)
            else -> colors(R.array.gradient1)
        }
    }

    private fun colors(@ArrayRes res: Int): IntArray {
        return context.resources.getIntArray(res)
    }

}
