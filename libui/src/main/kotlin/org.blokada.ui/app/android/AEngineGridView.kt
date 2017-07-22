package org.blokada.ui.app.android

import android.support.v7.widget.RecyclerView
import android.support.v7.widget.StaggeredGridLayoutManager
import android.widget.FrameLayout
import android.content.Context
import android.util.AttributeSet
import org.blokada.lib.ui.R
import org.blokada.ui.framework.android.Spacing

class AEngineGridView(
        val ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    private val grid by lazy { findViewById(R.id.engine_grid) as RecyclerView }

    var landscape: Boolean = false
        set(value) {
            field = value
            grid.layoutManager = StaggeredGridLayoutManager(
                    if (value) 2 else 1,
                    StaggeredGridLayoutManager.VERTICAL
            )
        }

    override fun onFinishInflate() {
        super.onFinishInflate()
        grid.addItemDecoration(Spacing(context))
        grid.adapter = AEngineAdapter(ctx)
        landscape = false
    }
}

