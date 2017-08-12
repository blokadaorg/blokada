package org.blokada.ui.app.android

import org.blokada.lib.ui.R
import android.util.AttributeSet
import android.content.Context

class AFiltersAddView(
        ctx: Context,
        attributeSet: AttributeSet
) : android.widget.FrameLayout(ctx, attributeSet) {

    enum class Tab { SINGLE, FILE, LINK, APP }

    var forceType: AFiltersAddView.Tab? = null
        set(value) {
            field = value
            if (ready) updateForce(value, showApp)
        }

    var showApp: Boolean = true
        set(value) {
            field = value
            if (ready) updateForce(forceType, value)
        }

    var currentTab = AFiltersAddView.Tab.SINGLE
        private set

    val appView by lazy {
        android.view.LayoutInflater.from(context).inflate(R.layout.view_filtersadd_app, pager, false)
                as AFiltersAddAppView
    }

    val singleView by lazy {
        android.view.LayoutInflater.from(context).inflate(R.layout.view_filtersadd_add, pager, false)
                as AFiltersAddSingleView
    }
    val fileView by lazy {
        android.view.LayoutInflater.from(context).inflate(R.layout.view_filtersadd_file, pager, false)
                as AFiltersAddFileView
    }

    val linkView by lazy {
        android.view.LayoutInflater.from(context).inflate(R.layout.view_filtersadd_link, pager, false)
                as AFiltersAddLinkView
    }

    private val pages by lazy { listOf(
            AFiltersAddView.Tab.SINGLE to Pair(R.string.filter_edit_name, singleView),
            AFiltersAddView.Tab.FILE to Pair(R.string.filter_edit_file, fileView),
            AFiltersAddView.Tab.LINK to Pair(R.string.filter_edit_link, linkView),
            AFiltersAddView.Tab.APP to Pair(R.string.filter_edit_app, appView)
    )}

    private var displayedPages: List<Pair<AFiltersAddView.Tab, Pair<Int, android.view.View>>>? = null

    private var ready = false

    private val pager by lazy { findViewById(R.id.filters_pager) as android.support.v4.view.ViewPager }

    override fun onFinishInflate() {
        super.onFinishInflate()

        ready = true
        pager.offscreenPageLimit = 3
        pager.adapter = object : android.support.v4.view.PagerAdapter() {

            override fun instantiateItem(container: android.view.ViewGroup, position: Int): Any {
                val view = displayedPages!![position].second.second
                container.addView(view)
                return view
            }

            override fun destroyItem(container: android.view.ViewGroup, position: Int, obj: Any) {
                container.removeView(obj as android.view.View)
            }

            override fun getPageTitle(position: Int): CharSequence {
                return context.getString(displayedPages!![position].second.first)
            }

            override fun getItemPosition(obj: Any?): Int {
                return POSITION_NONE // To reload on notifyDataSetChanged()
            }

            override fun getCount(): Int { return displayedPages?.size ?: 0 }
            override fun isViewFromObject(view: android.view.View?, obj: Any?): Boolean { return view == obj }
        }
        pager.setOnPageChangeListener(object : android.support.v4.view.ViewPager.OnPageChangeListener {
            override fun onPageSelected(position: Int) {
                currentTab = displayedPages!![position].first
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {}
            override fun onPageScrollStateChanged(state: Int) {}
        })
        updateForce(forceType, showApp)
    }

    private fun updateForce(value: AFiltersAddView.Tab?, showApp: Boolean) {
        if (value == null) {
            if (showApp) displayedPages = pages
            else displayedPages = pages.filter { it.first != AFiltersAddView.Tab.APP }
            appView.reset()
            singleView.reset()
            linkView.reset()
            fileView.reset()
            pager.currentItem = 0
            currentTab = AFiltersAddView.Tab.SINGLE
        } else {
            displayedPages = pages.filter { it.first == value }
            currentTab = value
        }
        pager.adapter.notifyDataSetChanged()
    }

}
