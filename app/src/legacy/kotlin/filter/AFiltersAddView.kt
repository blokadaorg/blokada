package filter

import android.content.Context
import android.util.AttributeSet
import org.blokada.R

class AFiltersAddView(
        ctx: Context,
        attributeSet: AttributeSet
) : android.widget.FrameLayout(ctx, attributeSet) {

    enum class Tab { SINGLE, FILE, LINK, APP }

    var forceType: Tab? = null
        set(value) {
            field = value
            if (ready) updateForce(value, showApp)
        }

    var showApp: Boolean = true
        set(value) {
            field = value
            if (ready) updateForce(forceType, value)
        }

    var currentTab = Tab.APP
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

    private val pages by lazy {
        listOf(
                Tab.APP to Pair(R.string.filter_edit_app, appView),
                Tab.LINK to Pair(R.string.filter_edit_link, linkView),
                Tab.SINGLE to Pair(R.string.filter_edit_name, singleView),
                Tab.FILE to Pair(R.string.filter_edit_file, fileView)
        )
    }

    private var displayedPages: List<Pair<Tab, Pair<Int, android.view.View>>>? = null

    private var ready = false

    private val pager by lazy { findViewById<android.support.v4.view.ViewPager>(R.id.filters_pager) }

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

            override fun getItemPosition(obj: Any): Int {
                return POSITION_NONE // To reload on notifyDataSetChanged()
            }

            override fun getCount(): Int {
                return displayedPages?.size ?: 0
            }

            override fun isViewFromObject(view: android.view.View, obj: Any): Boolean {
                return view == obj
            }
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

    private fun updateForce(value: Tab?, showApp: Boolean) {
        if (value == null) {
            displayedPages = if (showApp) pages
            else pages.filter { it.first != Tab.APP }
            appView.reset()
            singleView.reset()
            linkView.reset()
            fileView.reset()
            pager.currentItem = 0
            currentTab = displayedPages!!.first().first
        } else {
            displayedPages = pages.filter { it.first == value }
            currentTab = value
        }
        pager.adapter?.notifyDataSetChanged()
    }
}
