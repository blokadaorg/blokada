package core

import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import tunnel.Request
import java.util.*


class PacketsView(
        ctx: Context,
        attributeSet: AttributeSet
) : View(ctx, attributeSet), ActiveBackground {

    override fun onOpenSection(after: () -> Unit) {
    }

    override fun onCloseSection() {
    }

    private val pulsePaint: Paint
    private val barrierPaint: Paint
    private val items = mutableListOf<Request>()

    val color = resources.getColor(R.color.colorActive)
    val color3 = resources.getColor(R.color.colorAccent)

    private var showAnim = false
    private var tunnelOn = false

    private var on = false

    private val ktx = ctx.ktx("colorfulBackground")
    private val uiState by lazy { ktx.di().instance<UiState>() }


    init {
        pulsePaint = Paint(Paint.ANTI_ALIAS_FLAG);
        pulsePaint.setStrokeWidth(0f);
        pulsePaint.setStyle(Paint.Style.STROKE);
        pulsePaint.setColor(color);

        barrierPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        barrierPaint.setStrokeWidth(2f)
        barrierPaint.setPathEffect(DashPathEffect(floatArrayOf(4f, 2f), 0f))
        barrierPaint.setStyle(Paint.Style.STROKE)
        barrierPaint.setColor(color)

        uiState.showBgAnim.doOnUiWhenSet().then {
            showAnim = uiState.showBgAnim()
            on = tunnelOn && showAnim
            if (!on) items.clear()
        }
    }

    override fun onScroll(fraction: Float, oldPosition: Int, newPosition: Int) {
    }

    override fun onPositionChanged(position: Int) {
    }

    override fun setTunnelState(state: TunnelState) {
        tunnelOn = state == TunnelState.ACTIVE
        on = tunnelOn && showAnim
        if (!on) items.clear()
    }

    override fun setOnClickSwitch(onClick: () -> Unit) {
    }

    override fun setRecentHistory(items: List<Request>) {
        this.items.clear()
        this.items.addAll(items)
    }

    override fun addToHistory(item: Request) {
        this.items.add(item)
        if (items.size > 100) items.removeAt(0)
    }

    private val base by lazy { Date().time - SystemClock.elapsedRealtime() }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!on) {
            postInvalidateOnAnimation()
            return
        }

        val WINDOW_MS = 60 * 1000
        val SCAN_MS = 600
        val FLASH_MS = 600
        val SCAN_SIZE = 0.10f
        val now = base + SystemClock.elapsedRealtime()

        val yoffset = 0
        val xoffset = 0
        val maxRadius = if (height > width) height else width

        for (item in items) {
            val age = now - item.time.time
            if (age > WINDOW_MS * (1 - SCAN_SIZE)) continue
            if (age < SCAN_MS) {
                val fraction = age.toFloat() / SCAN_MS
                val radius = fraction * (maxRadius * SCAN_SIZE)
                pulsePaint.setAlpha(255)
                canvas.drawCircle(xoffset.toFloat(), yoffset.toFloat(), radius, pulsePaint)
            } else if (!item.blocked && on) {
                val fraction = (age - SCAN_MS) / (WINDOW_MS * (1 - SCAN_SIZE))
                val radius = SCAN_SIZE * maxRadius + fraction * maxRadius
                val alpha = (255 * (1 - fraction)).toInt()
                pulsePaint.setAlpha(alpha)
                canvas.drawCircle(xoffset.toFloat(), yoffset.toFloat(), radius, pulsePaint)
            } else if (age <= SCAN_MS + FLASH_MS) {
                val fraction = (age - SCAN_MS) / FLASH_MS.toFloat()
                val radius = SCAN_SIZE * maxRadius + fraction * (SCAN_SIZE * maxRadius * 1.3f)
                val alpha = (255 * (0 - (age - SCAN_MS - FLASH_MS)).toInt() / FLASH_MS)

                barrierPaint.color = color
                barrierPaint.alpha = alpha
                canvas.drawCircle(xoffset.toFloat(), yoffset.toFloat(), radius, barrierPaint)

                barrierPaint.color = color3
                barrierPaint.alpha = alpha
                canvas.drawCircle(xoffset.toFloat(), yoffset.toFloat(), maxRadius * SCAN_SIZE, barrierPaint)
            }
        }

        postInvalidateOnAnimation()
    }

    override fun onMeasure(w: Int, h: Int) {
        val wMode = View.MeasureSpec.getMode(w)
        val width: Int
        if (wMode == View.MeasureSpec.AT_MOST || wMode == View.MeasureSpec.EXACTLY) {
            // Always fill the whole width.
            width = View.MeasureSpec.getSize(w)
        } else {
            width = suggestedMinimumWidth
        }

        val hMode = View.MeasureSpec.getMode(h)
        var height: Int
        if (hMode == View.MeasureSpec.EXACTLY) {
            // Nothing we can do about it.
            height = View.MeasureSpec.getSize(h)
        } else {
            // Fill 80% of the height.
            val screenHeight = resources.displayMetrics.heightPixels
            height = (0.8 * screenHeight).toInt()
            if (hMode == View.MeasureSpec.AT_MOST) {
                height = Math.min(height, View.MeasureSpec.getSize(h))
            }
        }

        setMeasuredDimension(width, height)
    }

}
