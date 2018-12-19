package core

import android.app.Activity
import android.app.UiModeManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.support.annotation.RequiresApi
import android.view.View
import android.view.WindowManager
import com.github.michaelbull.result.onFailure
import com.github.salomonbrys.kodein.instance
import gs.environment.ComponentProvider
import gs.obsolete.Sync
import kotlinx.coroutines.experimental.runBlocking
import nl.komponents.kovenant.task
import org.blokada.R
import tunnel.RestApi
import tunnel.RestModel
import tunnel.askTunnelPermission
import tunnel.tunnelPermissionResult
import java.lang.ref.WeakReference


class PanelActivity : Activity() {

    private val ktx = ktx("PanelActivity")
    private val dashboardView by lazy { findViewById<DashboardView>(R.id.DashboardView) }
    private val tunnelManager by lazy { ktx.di().instance<tunnel.Main>() }
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val activityContext by lazy { ktx.di().instance<ComponentProvider<Activity>>() }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.dashboard)
//        setFullScreenWindowLayoutInDisplayCutout(window)
        activityRegister.register(this)
        dashboardView.onSectionClosed = {
            filters.changed %= true
        }
        activityContext.set(this)
        getNotch()
    }

    override fun onResume() {
        super.onResume()
        modalManager.closeModal()
    }

    override fun onBackPressed() {
        if (!dashboardView.handleBackPressed()) super.onBackPressed()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        tunnelPermissionResult(Kontext.new("permission:vpn:result"), resultCode)
    }

    fun trai() {
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN // Set layout full screen
        if (Build.VERSION.SDK_INT >= 28) {
            val lp = window.attributes
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = lp
        }
    }

    @RequiresApi(28)
    private fun getNotch() {
        try {
            val displayCutout = window.decorView.rootWindowInsets.displayCutout
            dashboardView.notchPx = displayCutout.safeInsetTop
        } catch (e: Throwable) {
            if (!isAndroidTV())
                dashboardView.notchPx = resources.getDimensionPixelSize(R.dimen.dashboard_notch_inset)
        }
    }

    private fun isAndroidTV(): Boolean {
        val uiModeManager = getSystemService(UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }
}

val modalManager = ModalManager()
val activityRegister = ActiveActivityRegister()

class ActiveActivityRegister {

    private var activity = Sync(WeakReference(null as Activity?))

    fun register(activity: Activity) {
        this.activity = Sync(WeakReference(activity))
    }

    fun askPermissions() {
        val act = activity.get().get() ?: throw Exception("starting MainActivity")
        val deferred = askTunnelPermission(Kontext.new("static perm ask"), act)
        runBlocking {
            val response = deferred.await()
            if (!response) { throw Exception("could not get tunnel permissions") }
        }
    }

    fun getParentView(): View? {
        return activity.get().get()?.findViewById(R.id.root)
    }
}
