package org.blokada.ui.framework.android

import android.animation.Animator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Resources
import android.graphics.Rect
import android.support.v7.widget.RecyclerView
import android.util.TypedValue
import android.view.View
import android.view.ViewPropertyAnimator

/**
 * Dev tools and the play store (and others?) launch with a different intent, and so
 * lead to a redundant instance of this activity being spawned. <a
 * href="http://stackoverflow.com/questions/17702202/find-out-whether-the-current-activity-will-be-task-root-eventually-after-pendin"
 * >Details</a>.
 */
fun isWrongInstance(a: Activity): Boolean {
    if (!a.isTaskRoot) {
        val intent = a.intent;
        val isMainAction = intent.action != null && intent.action.equals(Intent.ACTION_MAIN);
        return intent.hasCategory(Intent.CATEGORY_LAUNCHER) && isMainAction;
    }
    return false;
}

fun ViewPropertyAnimator.doAfter(f: () -> Unit) {
    this.setListener(object : Animator.AnimatorListener {
        override fun onAnimationEnd(p0: Animator?) {
            this@doAfter.setListener(null)
            f()
        }

        override fun onAnimationRepeat(p0: Animator?) {}

        override fun onAnimationCancel(p0: Animator?) {
            this@doAfter.setListener(null)
            f()
        }

        override fun onAnimationStart(p0: Animator?) {}
    }).start()
}

fun Resources.toPx(dp: Int): Int {
    return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(),
            this.displayMetrics).toInt();
}

class Spacing(val ctx: Context,
              val top: Int = 8, val bottom: Int = 0,
              val left: Int = 4, val right: Int = 4
) : RecyclerView.ItemDecoration() {
    override fun getItemOffsets(outRect: Rect, view: View?, parent: RecyclerView?,
                                state: RecyclerView.State?) {
        outRect.top = ctx.resources.toPx(top)
        outRect.bottom = ctx.resources.toPx(bottom)
        outRect.right = ctx.resources.toPx(right)
        outRect.left = ctx.resources.toPx(left)
    }
}
