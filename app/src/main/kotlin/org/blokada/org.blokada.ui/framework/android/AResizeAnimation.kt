package org.blokada.ui.framework.android

import android.view.View
import android.view.animation.Animation
import android.view.animation.Transformation

class AResizeAnimation(var view: View, val targetHeight: Int, var startHeight: Int,
                       var square: Boolean) : Animation() {

    override fun applyTransformation(interpolatedTime: Float, t: Transformation) {
        val newHeight = (startHeight + (targetHeight - startHeight) * interpolatedTime).toInt()
        view.layoutParams.height = newHeight
        if (square) view.layoutParams.width = newHeight
        view.requestLayout()
    }

    override fun initialize(width: Int, height: Int, parentWidth: Int, parentHeight: Int) {
        super.initialize(width, height, parentWidth, parentHeight)
    }

    override fun willChangeBounds(): Boolean {
        return true
    }
}