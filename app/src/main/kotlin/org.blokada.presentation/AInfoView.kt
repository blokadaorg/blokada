package org.blokada.presentation

import android.content.Context
import android.text.Html
import android.util.AttributeSet
import android.widget.TextView
import nl.komponents.kovenant.ui.promiseOnUi
import gs.presentation.doAfter


class AInfoView(
        private val ctx: Context,
        private val attributeSet: AttributeSet
): TextView(ctx, attributeSet) {

    var waitMillis: Int? = null

    var message = ""
        set(value) {
            field = value
            if (shown) {
                shown = false
                slideOut {
                    text = Html.fromHtml(value)
                    shown = true
                    slideIn()
                }
            } else {
                promiseOnUi {
                    text = Html.fromHtml(value)
                }
                shown = true
                slideIn()
            }
            Thread.sleep(calculateWait())
        }

    var shown = true
        set(value) { when(value) {
            field -> Unit
            else -> field = value
        }}

    init {
//        movementMethod = LinkMovementMethod()
    }

    private fun slideIn(after: () -> Unit = {}) {
        if (!shown) return
        promiseOnUi {
            animate().alpha(1f).doAfter { after() }
        }
    }

    private fun slideOut(after: () -> Unit = {}) {
        if (shown) return
        promiseOnUi {
            animate().alpha(0f).doAfter { after() }
        }
    }

    private fun calculateWait(): Long {
        return if (waitMillis != null) waitMillis!!.toLong()
        else 2000L * text.length / 50
    }
}
