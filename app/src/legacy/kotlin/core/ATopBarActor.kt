package core

import android.view.View
import android.view.Window
import android.view.animation.DecelerateInterpolator
import gs.environment.Environment
import gs.presentation.ResizeAnimation
import org.blokada.R

class ATopBarActor(
        private val xx: Environment,
        private val m: Tunnel,
        private val ui: UiState,
        private val v: ATopBarView,
        private val enabledStateActor: EnabledStateActor,
        private val contentActor: ContentActor,
        private val infoView: AInfoView,
        private val infoViewShadow: View,
        private val shadow: View,
        private val window: Window,
        private val pages: Pages
) : IEnabledStateActorListener {

    var dash1: Dash? = null
        set(value) { field = handleDashChange(value, v.action1, dashActor1) }
    var dash2: Dash? = null
        set(value) { field = handleDashChange(value, v.action2, dashActor2) }
    var dash3: Dash? = null
        set(value) { field = handleDashChange(value, v.action3, dashActor3) }

    private val dashActor1: ADashActor = ADashActor(DashNoop(), v.action1, ui, contentActor)
    private val dashActor2: ADashActor = ADashActor(DashNoop(), v.action2, ui, contentActor)
    private val dashActor3: ADashActor = ADashActor(DashNoop(), v.action3, ui, contentActor)

    private var initialInfoViewHeight: Int? = null

    init {
        shadow.alpha = 0f

        v.onLogoClick = {
            m.enabled %= !m.enabled()
        }

        v.onModeSwitched = {
            if (initialInfoViewHeight == null) { initialInfoViewHeight = infoView.measuredHeight }

            // Bar mode configuration
            var bg = v.bg ?: R.color.colorBackgroundLight
            var shadowAlpha = 1f
            var infoAlpha = 1f
            var toInfoHeight = initialInfoViewHeight!!

            when (v.mode) {
                ATopBarView.Mode.WELCOME -> {
                    bg = R.color.colorBackground
                    shadowAlpha = 0f
                }
                ATopBarView.Mode.BACK -> {
                    infoAlpha = 0f
                    toInfoHeight = 0
                }
            }

            shadow.animate().alpha(shadowAlpha)

            val a = ResizeAnimation(infoView, toInfoHeight, infoView.measuredHeight, square = false)
            a.duration = 300
            a.interpolator = DecelerateInterpolator(1.3f)
            infoView.startAnimation(a)
            infoView.animate().alpha(infoAlpha)
            infoViewShadow.animate().alpha(infoAlpha)

            if (android.os.Build.VERSION.SDK_INT >= 21) {
//                window.statusBarColor = v.resources.getColor(bg)
            }
        }

        v.onBackClick = { contentActor.back() }

        contentActor.onDashOpen += { dash -> when(dash) {
            null -> resetActions()
            else -> {
                val dashes = dash.menuDashes
                dash1 = dashes.first
                dash2 = dashes.second
                dash3 = dashes.third
            }
        }}

        resetActions()
        v.action4.showClickAnim = false
        ADashActor(DashMainMenu(v.context, ui, contentActor), v.action4, ui, contentActor)
        enabledStateActor.listeners.add(this)
    }

    fun resetActions() {
        dash1 = null
        dash2 = null
        dash3 = ChatDash(v.context, pages.chat)
    }

    private fun handleDashChange(dash: Dash?, dashView: ADashView, dashActor: ADashActor): Dash? {
        if (dash == null) {
            dashView.visibility = View.GONE
        } else {
            dashView.visibility = View.VISIBLE
            dashActor.dash = dash
            dash.text = null // Menu dashes cannot display text
        }
        return dash
    }

    override fun startActivating() {
        v.waiting = true
    }

    override fun finishActivating() {
        v.waiting = false
        v.active = true
    }

    override fun startDeactivating() {
        v.waiting = true
    }

    override fun finishDeactivating() {
        v.waiting = false
        v.active = false
    }
}
