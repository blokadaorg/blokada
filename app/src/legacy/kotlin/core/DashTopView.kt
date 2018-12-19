package core

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import org.blokada.R

class DashTopView(
        ctx: Context,
        attributeSet: AttributeSet
) : LinearLayout(ctx, attributeSet) {

    private val bigView by lazy { findViewById<TextView>(R.id.big) }
    private val smallView by lazy { findViewById<TextView>(R.id.small) }

    var big: String = ""
        set(value) {
            field = value
            bigView.text = value
        }

    var small: String? = null
        set(value) {
            field = value
            if (value != null) {
                smallView.visibility = View.VISIBLE
                smallView.text = value
            } else {
                smallView.visibility = View.GONE
            }
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        small = null
    }

}
