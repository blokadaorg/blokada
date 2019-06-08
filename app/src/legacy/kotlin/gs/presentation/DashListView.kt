package gs.presentation

import android.content.Context
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.StaggeredGridLayoutManager
import android.util.AttributeSet
import gs.presentation.DashAdapter
import gs.presentation.Spacing

class DashListView(
        ctx: Context,
        attributeSet: AttributeSet
) : RecyclerView(ctx, attributeSet) {

    val adapter = DashAdapter(context)

    var landscape: Boolean = false
        set(value) {
            field = value
            layoutManager = StaggeredGridLayoutManager(
                    if (value) 2 else 1,
                    StaggeredGridLayoutManager.VERTICAL
            )
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        addItemDecoration(Spacing(context))
        setAdapter(adapter)
        landscape = false
    }


}
