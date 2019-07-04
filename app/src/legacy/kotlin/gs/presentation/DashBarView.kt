package gs.presentation

import android.content.Context
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.StaggeredGridLayoutManager
import android.util.AttributeSet

class DashBarView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    val adapter = DashAdapter(context)

    var landscape: Boolean = false
        set(value) {
            field = value
            layoutManager = StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL)
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setAdapter(adapter)
        addItemDecoration(Spacing(context, top = 6, left = 2, right = 2, bottom = 6))
        landscape = false
    }

}

