package gs.presentation

import android.graphics.Rect
import android.support.v7.widget.RecyclerView
import android.view.View

/**
 * Dev tools and the play store (and others?) launch with a different intent, and so
 * lead to a redundant instance of this activity being spawned. <a
 * href="http://stackoverflow.com/questions/17702202/find-out-whether-the-current-activity-will-be-task-root-eventually-after-pendin"
 * >Details</a>.
 */
fun isWrongInstance(a: android.app.Activity): Boolean {
    if (!a.isTaskRoot) {
        val intent = a.intent;
        val isMainAction = intent.action != null && intent.action.equals(android.content.Intent.ACTION_MAIN);
        return intent.hasCategory(android.content.Intent.CATEGORY_LAUNCHER) && isMainAction;
    }
    return false;
}

fun android.view.ViewPropertyAnimator.doAfter(f: () -> Unit) {
    this.setListener(object : android.animation.Animator.AnimatorListener {
        override fun onAnimationEnd(p0: android.animation.Animator?) {
            this@doAfter.setListener(null)
            f()
        }

        override fun onAnimationRepeat(p0: android.animation.Animator?) {}

        override fun onAnimationCancel(p0: android.animation.Animator?) {
            this@doAfter.setListener(null)
            f()
        }

        override fun onAnimationStart(p0: android.animation.Animator?) {}
    }).start()
}

fun android.content.res.Resources.toPx(dp: Int): Int {
    return android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(),
            this.displayMetrics).toInt();
}

class Spacing(val ctx: android.content.Context,
              val top: Int = 8, val bottom: Int = 0,
              val left: Int = 4, val right: Int = 4
) : android.support.v7.widget.RecyclerView.ItemDecoration() {
    override fun getItemOffsets(outRect: Rect, view: View, parent: RecyclerView, state: RecyclerView.State) {
        super.getItemOffsets(outRect, view, parent, state)
        outRect.top = ctx.resources.toPx(top)
        outRect.bottom = ctx.resources.toPx(bottom)
        outRect.right = ctx.resources.toPx(right)
        outRect.left = ctx.resources.toPx(left)
    }
}
