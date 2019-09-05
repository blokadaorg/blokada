package core

import android.content.Context
import android.graphics.PorterDuff
import android.os.Handler
import android.util.AttributeSet
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.content.ContextCompat.getColorStateList
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager.widget.ViewPager
import com.github.michaelbull.result.onFailure
import com.github.michaelbull.result.onSuccess
import com.github.salomonbrys.kodein.instance
import com.sothree.slidinguppanel.SlidingUpPanelLayout
import core.bits.AdsDashboardSectionVB
import core.bits.HomeDashboardSectionVB
import core.bits.menu.MENU_CLICK
import core.bits.menu.MENU_CLICK_BY_NAME
import core.bits.menu.MenuItemVB
import core.bits.menu.createMenu
import gs.environment.inject
import gs.presentation.NamedViewBinder
import gs.presentation.doAfter
import gs.property.I18n
import org.blokada.R
import tunnel.Events
import tunnel.Persistence
import kotlin.math.max
import kotlin.math.min


typealias PanelState = SlidingUpPanelLayout.PanelState

val OPEN_MENU = "DASHBOARD_OPEN_MENU".newEvent()
val SWIPE_RIGHT = "DASHBOARD_SWIPE_RIGHT".newEvent()

class DashboardView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet), Backable {

    init {
        inflate(context, R.layout.dashboard_content, this)
    }

    private val sliding = findViewById<SlidingUpPanelLayout>(R.id.panel)
    private val bg_colors = findViewById<ColorfulBackground>(R.id.bg_colors)
    private val bg_nav = findViewById<DotsView>(R.id.bg_nav)
    private val bg_logo = findViewById<LinearLayout>(R.id.bg_logo)
    private val bg_logo_icon = findViewById<ImageView>(R.id.bg_logo_icon)
    private val bg_pager = findViewById<VBPagesView>(R.id.bg_pager)
    private val bg_packets = findViewById<PacketsView>(R.id.bg_packets)
    private val fg_chevron_back = findViewById<View>(R.id.fg_chevron_back)
    private val bg_chevron_right = findViewById<View>(R.id.bg_chevron_right)
    private val fg_label = findViewById<FrameLayout>(R.id.fg_label)
    private val fg_logo_icon = findViewById<ImageView>(R.id.fg_logo_icon)
    private val fg_label_text = findViewById<TextView>(R.id.fg_label_text)
    private val fg_pager = findViewById<VBPagesView>(R.id.fg_pager)
    private val fg_drag = findViewById<View>(R.id.fg_drag)
    private val fg_nav_panel = findViewById<View>(R.id.fg_nav_panel)

    var notchPx: Int = 0
    var navigationBarPx: Int = 0
    var onSectionClosed = {}

    private val ktx = ctx.ktx("dashboard")

    private val tunnelEvents by lazy { ctx.inject().instance<EnabledStateActor>() }
    private val tun by lazy { ctx.inject().instance<Tunnel>() }
    private val i18n by lazy { ctx.inject().instance<I18n>() }

    private var scrolledView: View? = null

    private var lastSubsectionTab = 0
    private var previousMeaningfulState = PanelState.DRAGGING

    private val mainMenu = createMenu(ktx)

    private val model by lazy {
        DashboardNavigationModel(
                createDashboardSections(ktx),
                mainMenu,
                onChangeSection = { section, sectionIndex ->
                    ktx.v("onChangeSection")
                    setMainSectionLabelAndMenuIcon(section)
                    bg_pager.currentItem = sectionIndex
                },
                onChangeMenu = { submenu, secondarySubmenu ->
                    ktx.v("onChangeMenu")
                    setMenu()
                    setMenuNav(submenu, secondarySubmenu)
                    bg_pager.lock = true
                    onOpenSection { }
                },
                onMenuClosed = { sectionIndex ->
                    ktx.v("onMenuClosed")
                    setOn(sectionIndex + 1)
                    bg_pager.lock = false
                    updateMenuHeader(null, closed = true)
                    onCloseSection()
                },
                onOpenMenu = {
                    sliding.panelState = PanelState.EXPANDED
                },
                onCloseMenu = {
                    sliding.panelState = PanelState.ANCHORED
                },
                onBackSubmenu = {
                    fg_pager.currentItem = fg_pager.currentItem - 1
                }
        )
    }

    override fun onFinishInflate() {
        super.onFinishInflate()
        setupParentContainer()
        setupSlidingPanel()
        setupBg()
        setupExternalEventListeners()
        setupMenu()
        adjustMargins()
        listenToEvents()
        setOn(0)
        Handler {
            // Workaround for a bug in this library that makes it stay open on orientation change
            sliding.panelState = PanelState.ANCHORED
            true
        }.sendEmptyMessage(0)
    }

    fun createDashboardSections(ktx: AndroidKontext): List<NamedViewBinder> {
        val di = ktx.di()
        val pages: Pages = di.instance()

        return listOf(
                HomeDashboardSectionVB(ktx),
                AdsDashboardSectionVB(ktx)
        )
    }

    private fun listenToEvents() {
        ktx.on(OPEN_MENU, callback = {
            sliding.panelState = PanelState.EXPANDED
//            model.menuViewPagerSwiped(0)
        }, recentValue = false)

        ktx.on(SWIPE_RIGHT, callback = {
            bg_pager.currentItem = 1
        }, recentValue = false)

        ktx.on(MENU_CLICK, callback = { item ->
            model.menuItemClicked(item)
        }, recentValue = false)

        ktx.on(MENU_CLICK_BY_NAME, callback = { item ->
            val found = mainMenu.items.firstOrNull { (it as? NamedViewBinder)?.name == item } as NamedViewBinder?
            found?.run {
                sliding.panelState = PanelState.EXPANDED
                Handler {
                    if (this is MenuItemVB) model.menuItemClicked(opens)
                    else model.menuItemClicked(this)
                    true
                }.sendEmptyMessageDelayed(0, 1000)
            }
        }, recentValue = false)

        tun.enabled.doOnUiWhenSet().then {
            if (tun.enabled()) bg_colors.onScroll(1f, 4, model.getOpenedSectionIndex() + 1)
            else bg_colors.onScroll(1f, model.getOpenedSectionIndex() + 1, 4)
        }
    }

    private fun setOn(toColorIndex: Int) {
        ktx.v("setOn")
        //bg_colors.onScroll(1f, 0, toColorIndex)
        bg_nav.alpha = 1f
        bg_logo.alpha = 1.0f
        bg_packets.alpha = 1f
        fg_pager.alpha = 0f
        bg_pager.visibility = View.VISIBLE
        bg_pager.alpha = 1f

        val lp = fg_drag.layoutParams as FrameLayout.LayoutParams
        lp.height = resources.getDimensionPixelSize(R.dimen.dashboard_fg_drag_height)
        lp.topMargin = resources.getDimensionPixelSize(R.dimen.dashboard_fg_drag_margin_top)
        fg_drag.layoutParams = lp
    }

    private fun setMenu() {
        ktx.v("setMenu")
//        bg_colors.onScroll(1f, 0, toColorIndex)
        bg_logo.alpha = 1f
        bg_packets.alpha = 1f
        fg_pager.alpha = 1f
        fg_chevron_back.alpha = 1f
        bg_pager.alpha = 0f

        val lp = fg_drag.layoutParams as FrameLayout.LayoutParams
        lp.height = resources.getDimensionPixelSize(R.dimen.dashboard_fg_drag_height)
        lp.topMargin = 0
        fg_drag.layoutParams = lp
    }

    private fun setDragging() {
        fg_pager.alpha = 0f
        fg_chevron_back.alpha = 0f

        val lp = fg_label.layoutParams as FrameLayout.LayoutParams
        lp.topMargin = 0
        fg_label.requestLayout()
    }

    private val advanced by lazy { getColorStateList(ctx, R.color.dashboard_menu_advanced) }
    private val tintAdvanced = resources.getColor(R.color.gradient4_c3)
    private val adblocking by lazy { getColorStateList(ctx, R.color.dashboard_menu_adblocking) }
    private val tintAdblocking = resources.getColor(R.color.gradient3_c3)
    private val tintNormal = resources.getColor(R.color.colorText)

    private fun setMainSectionLabelAndMenuIcon(section: NamedViewBinder) {
        bg_nav.section = i18n.getString(section.name)
        fg_nav_panel.backgroundTintMode = PorterDuff.Mode.MULTIPLY
    }

    private fun setMenuNav(submenu: NamedViewBinder?, secondarySubmenu: NamedViewBinder?) {
        val (pages, current) = when {
            secondarySubmenu != null && submenu != null -> listOf(mainMenu, submenu, secondarySubmenu) to 2
            submenu != null -> listOf(mainMenu, submenu) to 1
            else -> listOf(mainMenu) to 0
        }

        val label = if (submenu == null) {
            null
        } else if (secondarySubmenu == null) {
            i18n.getString(submenu.name)
        } else {
            i18n.getString(secondarySubmenu.name)
        }

        updateMenuHeader(label)

        fg_pager.pages = pages
        if (current > lastSubsectionTab) {
            fg_pager.currentItem = max(current - 1, 0)
            Handler {
                fg_pager.currentItem = current
                true
            }.sendEmptyMessageDelayed(0, 50)
        } else {
            fg_pager.currentItem = current
        }
    }

    private fun updateMenuHeader(label: String?, closed: Boolean = false) {
        if (label == null) {
            fg_label_text.animate().setDuration(200).alpha(0f).doAfter {
                fg_label_text.visibility = View.GONE
            }
            fg_chevron_back.visibility = View.INVISIBLE
        } else {
            fg_label_text.visibility = View.VISIBLE
            fg_label_text.animate().setDuration(200).alpha(0f).doAfter {
                fg_label_text.text = label
                fg_label_text.animate().setDuration(200).alpha(1f)
            }
            fg_chevron_back.visibility = View.VISIBLE
        }
        if (closed) {
            fg_logo_icon.visibility = View.VISIBLE
        } else {
            fg_logo_icon.visibility = View.GONE
        }
    }

    private fun setupExternalEventListeners() {
        ktx.on(Events.REQUEST) {
            bg_packets.addToHistory(it)
        }

        tunnelEvents.listeners.add(object : IEnabledStateActorListener {
            override fun startActivating() {
                bg_packets.setTunnelState(TunnelState.ACTIVATING)
                bg_logo_icon.setColorFilter(resources.getColor(R.color.colorLogoWaiting))
            }

            override fun finishActivating() {
                bg_packets.setTunnelState(TunnelState.ACTIVE)
                bg_logo_icon.setColorFilter(resources.getColor(android.R.color.transparent))
                Persistence.request.load(0).onSuccess {
                    bg_packets.setRecentHistory(it)
                }
            }

            override fun startDeactivating() {
                bg_packets.setTunnelState(TunnelState.DEACTIVATING)
                bg_logo_icon.setColorFilter(resources.getColor(R.color.colorLogoWaiting))
            }

            override fun finishDeactivating() {
                bg_packets.setTunnelState(TunnelState.INACTIVE)
                bg_logo_icon.setColorFilter(resources.getColor(R.color.colorLogoInactive))
            }
        })
    }

    private fun setupParentContainer() {
        isFocusable = true
        setDragView(fg_drag)
        descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
    }

    private fun setupSlidingPanel() {
        sliding.apply {
            panelHeight = resources.getDimensionPixelSize(R.dimen.dashboard_panel_height)
            shadowHeight = 0
            isOverlayed = true

            addPanelSlideListener(object : SlidingUpPanelLayout.PanelSlideListener {
                override fun onPanelSlide(panel: View?, slideOffset: Float) {
                    if (slideOffset < anchorPoint) {
                        val ratio = slideOffset / anchorPoint
                        //bg_colors.onScroll(1 - ratio, model.getOpenedSectionIndex() + 1, 0)
                        // bg_start.alpha = 1 - min(1f, ratio)
                        bg_packets.alpha = min(1f, ratio)
                        bg_pager.alpha = min(1f, ratio)
                    } else {
                        fg_nav_panel.alpha = max(0.7f, slideOffset)
                        bg_pager.alpha = 1 - min(1f, (slideOffset - anchorPoint) * 3)
                        //bg_logo.alpha = 0.6f + (slideOffset - anchorPoint) / (0.4f - anchorPoint)
                    }
                }

                override fun onPanelStateChanged(panel: View, previousState: PanelState, newState: PanelState) {
                    when (newState) {
                        PanelState.DRAGGING -> {
                            ktx.v("panel dragging")
                            setDragging()
                        }
                        PanelState.ANCHORED -> {
                            ktx.v("panel anchored")
                            model.menuClosed()
                            if (previousMeaningfulState == PanelState.COLLAPSED && !tun.enabled()) {
                                ktx.v("enabling app as panel got anchored from collapsed state")
                                tun.error %= false
                                tun.enabled %= true
                            }
                            previousMeaningfulState = PanelState.ANCHORED
                        }
                        PanelState.COLLAPSED -> {
                            ktx.v("panel collapsed")
                            sliding.panelState = PanelState.ANCHORED
                        }
                        PanelState.EXPANDED -> {
                            ktx.v("panel expanded")
                            model.menuOpened()
                            if (previousMeaningfulState == PanelState.COLLAPSED && !tun.enabled()) {
                                ktx.v("enabling app as panel got expanded from collapsed state")
                                tun.error %= false
                                tun.enabled %= true
                            }
                            previousMeaningfulState = PanelState.EXPANDED
                        }
                    }
                }
            })
        }
    }

    private fun setupBg() {
        bg_pager.pages = model.sections

        bg_nav.viewPager = bg_pager
        bg_nav.sleeping = false

        lastSubsectionTab = 0
        bg_pager.currentItem = 0
        bg_pager.offscreenPageLimit = 3

        bg_pager.addOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {}

            override fun onPageScrolled(position: Int, positionOffset: Float, posPixels: Int) {
                if (tun.enabled()) {
                    val next = position + 1
                    bg_colors.onScroll(positionOffset, next, next + 1)
                }
            }

            override fun onPageSelected(position: Int) {
                model.mainViewPagerSwiped(position)
                lastSubsectionTab = 0
            }
        })

        fg_chevron_back.setOnClickListener {
            fg_pager.currentItem = fg_pager.currentItem - 1
        }

        bg_chevron_right.setOnClickListener {
            model.mainViewPagerSwipedRight()
        }

        model.getOpenedSection().run {
            bg_nav.section = i18n.getString(name)
            bg_pager.currentItem = model.getOpenedSectionIndex()
        }

        bg_packets.setTunnelState(tun.tunnelState())

        fg_pager.offscreenPageLimit = 5

        bg_logo_icon.setOnClickListener {
            when (sliding.panelState) {
                PanelState.EXPANDED -> sliding.panelState = PanelState.ANCHORED
                PanelState.ANCHORED -> sliding.panelState = PanelState.EXPANDED
            }
        }
    }

    private var adjusted = false
    private fun adjustMargins() {
        if (!adjusted) viewTreeObserver.addOnGlobalLayoutListener(::resize)
    }

    private fun resize() {
        if (adjusted) return
        adjusted = true
        ktx.v("resize")
        val percentHeight = (
                resources.getDimensionPixelSize(R.dimen.dashboard_panel_anchor_size)
                        + navigationBarPx
                ).toFloat() / height
        sliding.anchorPoint = percentHeight

        bg_logo.addToTopMargin(notchPx)
        bg_pager.addToTopMargin(notchPx)
        bg_nav.addToTopMargin(notchPx)
        fg_pager.addToTopMargin(notchPx)
        fg_logo_icon.addToTopMargin(notchPx)
        fg_logo_icon.addToBottomMargin(notchPx)

        bg_pager.addToBottomMargin(navigationBarPx)
        fg_pager.addToBottomMargin(navigationBarPx)

        setNavPanelMargins()

        if (width >= resources.getDimensionPixelSize(R.dimen.dashboard_nav_align_end_width)) {
            bg_nav.alignEnd()
        }
    }

    private fun View.addToTopMargin(size: Int) {
        Result.of {
            val lp = layoutParams as RelativeLayout.LayoutParams
            lp.topMargin += size
        }.onFailure {
            val lp = layoutParams as FrameLayout.LayoutParams
            lp.topMargin += size
        }
    }

    private fun View.addToBottomMargin(size: Int) {
        Result.of {
            val lp = layoutParams as RelativeLayout.LayoutParams
            lp.bottomMargin += size
        }.onFailure {
            val lp = layoutParams as FrameLayout.LayoutParams
            lp.bottomMargin += size
        }
    }

    private fun setNavPanelMargins() {
        val lp = fg_nav_panel.layoutParams as FrameLayout.LayoutParams
        lp.bottomMargin = resources.getDimensionPixelSize(R.dimen.dashboard_panel_margin_bottom) - notchPx
        lp.topMargin = resources.getDimensionPixelSize(R.dimen.dashboard_panel_margin_top) + notchPx
    }

    private fun onOpenSection(after: () -> Unit) {
        ktx.v("onopensection")
        bg_nav.viewPager = fg_pager
        bg_nav.sleeping = false
        fg_pager.visibility = View.VISIBLE
        after()
    }

    private fun onCloseSection() {
        ktx.v("onclosesection")

        model.getOpenedSection().run {
            bg_nav.section = i18n.getString(name)
            bg_nav.viewPager = bg_pager
            bg_nav.sleeping = false
        }

        fg_pager.visibility = View.GONE
        fg_pager.pages = emptyList()
    }

    private fun setDragView(dragView: View?) {
        sliding.setDragView(dragView)
        dragView?.apply {
            setOnClickListener {
                when {
                    !isEnabled || !sliding.isTouchEnabled -> Unit
                    sliding.panelState == PanelState.EXPANDED -> sliding.panelState = PanelState.ANCHORED
                    else -> sliding.panelState = PanelState.EXPANDED
                }
            }
        }
    }

    private fun updateScrollableView() {
        scrolledView = try {
            val child = fg_pager.getChildAt(0)
            when (child) {
                is Scrollable -> child.getScrollableView()
                is ScrollView -> child
                is RecyclerView -> child
                is ListView -> child
                is GridView -> child
                else -> null
            }
        } catch (e: Exception) {
            null
        }
        sliding.setScrollableView(scrolledView)
    }

    override fun handleBackPressed() = model.backPressed()

    private fun setupMenu() {
        fg_pager.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, posPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                if (position < lastSubsectionTab) {
                    Handler {
                        model.menuViewPagerSwiped(position)
                        true
                    }.sendEmptyMessageDelayed(0, 300)
                }
                lastSubsectionTab = position
                updateScrollableView()
            }
        })
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_UP -> {
                model.upKey()
                true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                model.downKey()
                true
            }
            else -> false
        }
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            in buttonsEnter -> model.selectKey()
            in buttonsBack -> model.backPressed()
            KeyEvent.KEYCODE_DPAD_LEFT -> model.leftKey()
            KeyEvent.KEYCODE_DPAD_RIGHT -> model.rightKey()
        }
        return true
    }
}

val buttonsEnter = listOf(KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER)
val buttonsBack = listOf(KeyEvent.KEYCODE_BUTTON_B, KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_DEL,
        KeyEvent.KEYCODE_FORWARD_DEL, KeyEvent.KEYCODE_ESCAPE)

