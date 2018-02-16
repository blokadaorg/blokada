package org.blokada.presentation

import android.content.Context
import android.support.design.widget.FloatingActionButton
import android.util.AttributeSet
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import org.blokada.R
import gs.presentation.doAfter
import gs.presentation.toPx

class AFloaterView(
        ctx: Context,
        attributeSet: AttributeSet
) : FloatingActionButton(ctx, attributeSet) {

    var onClick = {}

    var icon: Int? = R.drawable.ic_power
        set(value) {
            when (value) {
                field -> Unit
                null -> {
                    toHide { field = value }
                }
                else -> {
                    toHide {
                        setImageResource(value)
                        setColorFilter(colorFilter) //TODO
                        fromHide {
                            field = value
                        }
                    }
                }
            }
        }

    var hide = false
        set(value) {
            when (value) {
                field -> Unit
                true -> toHide { field = value }
                else -> fromHide { field = value }
            }
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setOnClickListener {
            rotate(-20f, {
                rotate(40f, {
                    rotate(-20f, {
                        onClick()
                    })
                })
            })
        }
    }

    private val inter = AccelerateInterpolator(3f)
    private val inter2 = DecelerateInterpolator(3f)
    private val inter3 = AccelerateDecelerateInterpolator()

    private fun toHide(after: () -> Unit) {
        animate().setInterpolator(inter).setDuration(200).translationY(resources.toPx(100)
                .toFloat()).doAfter(after)
    }

    private fun fromHide(after: () -> Unit) {
        animate().setInterpolator(inter2).setDuration(200).translationY(0f).doAfter(after)
    }

    private fun rotate(how: Float, after: () -> Unit) {
        animate().rotationBy(how).setInterpolator(inter3).setDuration(100).doAfter(after)
    }

}
