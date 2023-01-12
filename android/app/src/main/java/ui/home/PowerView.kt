/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.home

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import org.blokada.R
import ui.utils.getColorFromAttr
import java.lang.Long.max
import java.lang.Long.min

class PowerView : View {

    var animate = false

    var cover = true
        set(value) {
            if (value != field) {
                field = value
                if (value) {
                    if (animate) coverAnimator.reverse()
                    else alphaCover = 255
                }
                else {
                    if (animate) coverAnimator.start()
                    else alphaCover = 0
                }
                invalidate()
            }
        }

    var loading = false
        set(value) {
            if (value != field) {
                field = value
                if (value) {
                    if (animate) loadingAnimator.start()
                    else alphaLoading = 255
                }
                else {
                    if (animate) loadingAnimator.reverse()
                    else alphaLoading = 0
                }
                invalidate()
            }
        }

    var blueMode = false
        set(value) {
            if (value != field) {
                field = value
                if (value) {
                    if (animate) blueAnimator.start()
                    else alphaBlue = 255
                }
                else {
                    if (animate) blueAnimator.reverse()
                    else alphaBlue = 0
                }
                invalidate()
            }
        }

    var orangeMode = false
        set(value) {
            if (value != field) {
                field = value
                if (value) {
                    if (animate) orangeAnimator.start()
                    else alphaOrange = 255
                }
                else {
                    if (animate) orangeAnimator.reverse()
                    else alphaOrange = 0
                }
                invalidate()
            }
        }

    /**
     * In the example view, this drawable is drawn above the text.
     */
    var exampleDrawable: Drawable? = null

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Load attributes
        val a = context.obtainStyledAttributes(
                attrs, R.styleable.PowerView, defStyle, 0)

        if (a.hasValue(R.styleable.PowerView_powerIcon)) {
            exampleDrawable = a.getDrawable(R.styleable.PowerView_powerIcon)
            exampleDrawable?.callback = this
        }

        iconPaint = Paint().apply {
            colorFilter =
                PorterDuffColorFilter(context.getColorFromAttr(R.attr.colorRingPlus1), PorterDuff.Mode.SRC_IN)
        }

        inactiveRingPaint = Paint().apply {
            color = context.getColorFromAttr(android.R.attr.shadowColor)
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }

        loadingRingPaint = Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }

        a.recycle()
    }

    private val w by lazy {
        contentWidth.toFloat()
    }

    private lateinit var iconPaint: Paint

    private lateinit var loadingRingPaint: Paint

    private lateinit var inactiveRingPaint: Paint

    private val libreRingPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                w / 4f,
                w / 4f,
                w / 2f,
                w / 3f,
                context.getColorFromAttr(R.attr.colorRingLibre1),
                context.getColorFromAttr(R.attr.colorRingLibre2),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }
    }

    private val plusRingPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                w / 4f,
                w / 4f,
                w / 2f,
                w / 3f,
                context.getColorFromAttr(R.attr.colorRingPlus1),
                context.getColorFromAttr(R.attr.colorRingPlus2),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }
    }

    private val orangeRingPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                w / 4f,
                w / 4f,
                w / 2f,
                w / 3f,
                context.getColor(R.color.orange),
                context.getColor(R.color.orange),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }
    }

    private val redRingPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                w / 4f,
                w / 4f,
                w / 2f,
                w / 3f,
                context.getColor(R.color.orange_2),
                context.getColor(R.color.red),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }
    }

    private val greenRingPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                w / 4f,
                w / 4f,
                w / 2f,
                w / 3f,
                context.getColor(R.color.retro_green2),
                context.getColor(R.color.green),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
            strokeWidth = ringWidth
            style = Paint.Style.STROKE
        }
    }

    private val offButtonPaint by lazy {
        Paint().apply {
            color = context.getColorFromAttr(android.R.attr.textColor)
            shader = LinearGradient(
                0f,
                0f,
                0f,
                contentWidth.toFloat(),
                ContextCompat.getColor(context, R.color.white),
                ContextCompat.getColor(context, R.color.gray_100),
                Shader.TileMode.CLAMP
            )
            isAntiAlias = true
        }
    }

    private val shadowPaint by lazy {
        Paint().apply {
            isAntiAlias = true
            color = context.getColorFromAttr(android.R.attr.shadowColor)
            maskFilter = BlurMaskFilter(blurRadius, BlurMaskFilter.Blur.NORMAL)
        }
    }

    private val innerShadowPaint by lazy {
        Paint().apply {
            isAntiAlias = true
            color = context.getColorFromAttr(android.R.attr.shadowColor)
            shader = RadialGradient(
                w / 2f,
                w / 2f,
                w / 2f,
                intArrayOf(
                    context.getColorFromAttr(android.R.attr.shadowColor),
                    context.getColorFromAttr(android.R.attr.shadowColor),
                    ContextCompat.getColor(context, R.color.black)
                ),
                floatArrayOf(
                    0f,
                    0.67f,
                    1f
                ),
                Shader.TileMode.CLAMP
            )
            maskFilter = BlurMaskFilter(blurRadius, BlurMaskFilter.Blur.NORMAL)
        }
    }

    private val contentWidth by lazy { width  }
    private val contentHeight by lazy { height }
    private var iconWidth = 160

    private val iconStart by lazy { contentWidth / 2 - iconWidth / 2 }
    private val iconStartHeight by lazy { contentHeight / 2 - iconWidth / 2 }

    private val edge = 40f
    private val ringWidth = 24f

    // shadow properties
    private var offsetX = 7f
    private var offsetY = 10f
    private var blurRadius = 5f

    private var loadingAnimator = ValueAnimator.ofInt(0, 255).apply {
        duration = 2000
        addUpdateListener {
            alphaLoading = it.animatedValue as Int
            invalidate()
        }
    }

    private var alphaLoading = 0

    private var alphaCover = 255
    private var coverAnimator = ValueAnimator.ofInt(255, 0).apply {
        duration = 200
        addUpdateListener {
            alphaCover = it.animatedValue as Int
            invalidate()
        }
    }

    private var alphaBlue = 0
    private var blueAnimator = ValueAnimator.ofInt(0, 255).apply {
        duration = 700
        addUpdateListener {
            alphaBlue = it.animatedValue as Int
            invalidate()
        }
    }

    private var alphaOrange = 0
    private var orangeAnimator = ValueAnimator.ofInt(0, 255).apply {
        duration = 700
        addUpdateListener {
            alphaOrange = it.animatedValue as Int
            invalidate()
        }
    }

    private var ping = 0L
        set(value) {
            if (value != field) {
                field = value
                if (field != 0L) {
                    pingAnimator.duration = max(300, min(field * 5, 3000))
                    pingAnimator.start()
                    invalidate()
                }
            }
        }

    private var alphaPing = 0
    private var pingAnimator = ValueAnimator.ofInt(255, 0).apply {
        duration = 3000
        addUpdateListener {
            alphaPing = it.animatedValue as Int
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val pingPaint = when {
            ping > 500 -> redRingPaint
            ping > 200 -> orangeRingPaint
            else -> greenRingPaint
        }
        pingPaint.alpha = alphaPing
        canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - edge * 2.1f, pingPaint)

        // ring inactive
        canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - ringWidth * 2.1f, inactiveRingPaint)

        // ring loading
        loadingRingPaint.alpha = alphaLoading
        canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - ringWidth * 2.1f, loadingRingPaint)

        // ring blue
        libreRingPaint.alpha = alphaBlue
        canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - ringWidth * 2.1f, libreRingPaint)

        // ring orange
        plusRingPaint.alpha = alphaOrange
        canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - ringWidth * 2.1f, plusRingPaint)

        // Filled background when active
        canvas.drawCircle(
            contentWidth / 2f,
            contentHeight / 2f,
            contentWidth / 2f - edge * 2,
            innerShadowPaint
        )

        // shadow and the off state cover
        shadowPaint.alpha = alphaCover
        offButtonPaint.alpha = alphaCover

        canvas.drawCircle(
            contentWidth / 2f,
            contentHeight / 2f,
            contentWidth / 2f - edge * 1.8f,
            shadowPaint
        )
        canvas.drawCircle(
            contentWidth / 2f,
            contentHeight / 2f,
            contentWidth / 2f - edge * 2,
            offButtonPaint
        )

        exampleDrawable?.let {
            it.setBounds(iconStart, iconStartHeight,
                    iconStart + iconWidth, iconStartHeight + iconWidth)
            it.colorFilter = when {
                orangeMode -> orange
                blueMode -> blue
                loading -> blue
                else -> black
            }
            it.draw(canvas)
        }
    }

    private val blue = PorterDuffColorFilter(context.getColorFromAttr(R.attr.colorRingLibre1), PorterDuff.Mode.SRC_IN)
    private val orange = PorterDuffColorFilter(context.getColorFromAttr(R.attr.colorRingPlus1), PorterDuff.Mode.SRC_IN)
    private val black = PorterDuffColorFilter(ContextCompat.getColor(context, R.color.black), PorterDuff.Mode.SRC_IN)

    fun start() {
    }

    fun stop() {
        ping = 0
    }

}