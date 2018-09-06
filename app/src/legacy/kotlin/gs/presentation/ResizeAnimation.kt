package gs.presentation

class ResizeAnimation(var view: android.view.View, val targetHeight: Int, var startHeight: Int,
                      var square: Boolean) : android.view.animation.Animation() {

    override fun applyTransformation(interpolatedTime: Float, t: android.view.animation.Transformation) {
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