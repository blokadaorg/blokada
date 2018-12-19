package gs.presentation

import org.blokada.R


class TopBar(
        val v: TopBarView,
        private val shadow: android.view.View,
        private val window: android.view.Window
) {

    var dash1: IconDash? = null
        set(value) { field = handleDashChange(value, v.action1, field) }
    var dash2: IconDash? = null
        set(value) { field = handleDashChange(value, v.action2, field) }
    var dash3: IconDash? = null
        set(value) { field = handleDashChange(value, v.action3, field) }
    var dash4: IconDash? = null
        set(value) { field = handleDashChange(value, v.action4, field) }

    var onBack = {}
        set(value) {
            field = value
            v.onBackClick = onBack
        }

    private var initialInfoViewHeight: Int? = null

    init {
        shadow.alpha = 0f

        v.onLogoClick = {
//            m.enabled %= !m.enabled()
        }

        v.onModeSwitched = {
            // Bar mode configuration
            var bg = v.bg ?: R.color.colorBackground
//            var bg = v.bg ?: R.color.colorBackgroundLight
            var shadowAlpha = 1f

            when (v.mode) {
                TopBarView.Mode.WELCOME -> {
                    bg = R.color.colorBackground
                    shadowAlpha = 0f
                }
                TopBarView.Mode.BACK -> {
                }
            }

            shadow.animate().alpha(shadowAlpha)

            if (android.os.Build.VERSION.SDK_INT >= 21) {
//                window.statusBarColor = v.resources.getColor(bg)
            }
        }

        v.action4.showClickAnim = false
    }

    private fun handleDashChange(dash: IconDash?, dashView: IconDashView, oldDash: IconDash?): IconDash? {
        oldDash?.detach(dashView)
        if (dash == null) {
            dashView.visibility = android.view.View.GONE
        } else {
            dashView.visibility = android.view.View.VISIBLE
            dash.attach(dashView)
        }
        return dash
    }

    fun startActivating() {
        v.waiting = true
    }

    fun finishActivating() {
        v.waiting = false
        v.active = true
    }

    fun startDeactivating() {
        v.waiting = true
    }

    fun finishDeactivating() {
        v.waiting = false
        v.active = false
    }
}
