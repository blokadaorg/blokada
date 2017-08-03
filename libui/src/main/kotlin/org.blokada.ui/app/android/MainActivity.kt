package org.blokada.ui.app.android

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.content.res.Configuration
import android.support.design.widget.CoordinatorLayout
import android.support.v7.app.AppCompatActivity
import android.widget.FrameLayout
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.LazyKodeinAware
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import io.codetail.widget.RevealFrameLayout
import nl.komponents.kovenant.task
import org.blokada.app.*
import org.blokada.app.android.startAskTunnelPermissions
import org.blokada.app.android.stopAskTunnelPermissions
import org.blokada.framework.IJournal
import org.blokada.framework.IWhen
import org.blokada.framework.KContext
import org.blokada.framework.Sync
import org.blokada.framework.android.AActivityContext
import org.blokada.framework.android.di
import org.blokada.lib.ui.R
import org.blokada.ui.app.Dash
import org.blokada.ui.app.Info
import org.blokada.ui.app.InfoType
import org.blokada.ui.app.UiState
import org.blokada.ui.framework.android.isWrongInstance
import java.lang.ref.WeakReference

class MainActivity : AppCompatActivity(), LazyKodeinAware {

    override val kodein = LazyKodein(di)

    var landscape = false

    private var infoView: AInfoView? = null
    private var grid: AGridView? = null
    private var topBar: ATopBarView? = null
    private var contentActor: ContentActor? = null

    private val enabledStateActor: EnabledStateActor by instance()
    private val activityContext: AActivityContext<MainActivity> by instance()
    private val j: IJournal by instance()

    private val s: State by instance()
    private val ui: UiState by instance()

    private val ictx: KContext by kodein.with("infotext").instance()
    private var currentlyDisplayed: InfoType? = null

    // TODO: less stuff in this class, more modules

    private var listener11: IWhen? = null
    private var listener12: IWhen? = null
    private var listener13: IWhen? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        activityContext.set(this)

        if (isWrongInstance(this)) {
            finish();
            return;
        }

        landscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

        setContentView(R.layout.activity_main)

        infoView = findViewById(R.id.info) as AInfoView
        enabledStateActor.listeners.add(enabledStateListener)

        topBar = findViewById(R.id.topbar) as ATopBarView

        val getRadiusSize = {
            val size = android.graphics.Point()
            windowManager.defaultDisplay.getSize(size)
            if (landscape) size.x.toFloat()
            else size.y.toFloat()
        }

        contentActor = ContentActor(
                ui = ui,
                reveal = findViewById(R.id.reveal) as RevealFrameLayout,
                revealContainer = findViewById(R.id.reveal_container) as FrameLayout,
                topBar = topBar!!,
                radiusSize = getRadiusSize()
        )

        ATopBarActor(
                m = s,
                v = topBar!!,
                enabledStateActor = enabledStateActor,
                contentActor = contentActor!!,
                infoView = infoView!!,
                infoViewShadow = findViewById(R.id.info_shadow),
                shadow = findViewById(R.id.shadow),
                window = window,
                ui = ui
        )

        grid = findViewById(R.id.grid) as AGridView
        grid?.ui = ui
        grid?.contentActor = contentActor

        val updateItems = {
            when (ui.editUi()) {
                true -> ui.dashes()
                else -> ui.dashes().filter(Dash::active)
            }
        }

        grid?.items = updateItems()
        listener11 = ui.dashes.doOnUiWhenSet().then {
            grid?.items = updateItems()
        }
        listener12 = ui.editUi.doOnUiWhenChanged().then {
            grid?.items = updateItems()
        }

        grid?.onScrollToTop = { isTop ->
            if (!isTop && !landscape) topBar?.mode = ATopBarView.Mode.BAR
        }

        val fab = findViewById(R.id.fab) as AFloaterView
        AFabActor(fab, s, enabledStateActor, contentActor!!)

        if (landscape) {
            topBar?.mode = ATopBarView.Mode.BAR
            grid?.setPadding(0, 0, 0, 0)
            grid?.landscape = true
            grid?.adapter = grid?.adapter // To refresh grid
            val lp = fab.layoutParams as CoordinatorLayout.LayoutParams
            lp.gravity = android.view.Gravity.BOTTOM or android.view.Gravity.RIGHT
            fab.layoutParams = lp
        }

        MainActivity.Companion.staticContext.set(java.lang.ref.WeakReference(this))
        listener13 = ui.seenWelcome.doOnUiWhenSet().then {
            val d = AWelcomeDialog(this)
            if (d.shouldShow()) {
                d.show()
                j.event(Events.Companion.FIRST_WELCOME)
            }
        }

//        if (Build.VERSION.SDK_INT >= 21) {
//            window.navigationBarColor = resources.getColor(R.color.colorBackground)
//        }
    }

    val activityResultListeners = mutableListOf({result: Int, data: Intent? -> })

    fun addOnNextActivityResultListener(listener: (result: Int, data: Intent?) -> Unit) {
        activityResultListeners.add(listener)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        activityResultListeners.forEach { it(resultCode, data) }
        activityResultListeners.clear()
        stopAskTunnelPermissions(resultCode)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        if (intent.getBooleanExtra("notification", false)) {
            val n: NotificationManager = di().instance()
            n.cancel(1)
        }
        if (intent.getBooleanExtra("askPermissions", false)) {
            j.log("Started main activity for askForPermissions permissions")
            task {
                try {
                    MainActivity.askPermissions()
                } catch (e: Exception) {
                    s.active %= false
                }
//                engineState.enabled.changed()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        infoListener = ui.infoQueue.doWhenChanged().then { infoQueueHandler(ui.infoQueue()) }
    }

    override fun onStop() {
        ui.infoQueue.cancel(infoListener)
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        enabledStateActor.update(s)
        infoQueueHandler(ui.infoQueue())
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onDestroy() {
//        staticContext.set(WeakReference(null as Activity?))
        super.onDestroy()
        activityContext.unset()
        enabledStateActor.listeners.remove(enabledStateListener)
    }

    override fun onBackPressed() {
        if (!(contentActor?.back() ?: false)) super.onBackPressed()
    }

    private val display = { i: Info ->
        currentlyDisplayed = if (i.type == InfoType.CUSTOM) null else i.type
        task(ictx) {
            infoView?.message = handleInfo(i)
        }
    }

    var infoListener: IWhen? = null
    val infoQueueHandler = { queue: List<Info> ->
        val queue = ui.infoQueue()
        when (queue.size) {
            0 -> Unit
            1 -> {
                if (queue.first().type != currentlyDisplayed) display(queue.first())
                ui.infoQueue %= emptyList()
            }
            in 2..4 -> {
                queue.forEach { display(it) }
                ui.infoQueue %= emptyList()
            }
            else -> {
                display(queue.last())
                ui.infoQueue %= emptyList()
            }
        }
    }

    private fun handleInfo(i: Info): String {
        return when (i.type) {
            InfoType.CUSTOM -> when {
                i.param is String -> i.param
                i.param is Int -> brandedString(i.param)
                else -> throw Exception("custom info without a param")
            }
            InfoType.ERROR -> brandedString(R.string.main_error)
            InfoType.PAUSED -> when {
                s.firstRun() -> brandedString(R.string.main_intro)
                else -> brandedRandomString(R.array.main_paused)
            }
            InfoType.PAUSED_TETHERING -> brandedString(R.string.main_paused_autoenable_tethering)
            InfoType.PAUSED_OFFLINE -> brandedString(R.string.main_paused_autoenable)
            InfoType.ACTIVATING -> when {
                s.firstRun() -> brandedString(R.string.main_activating_new)
                else -> brandedRandomString(R.array.main_activating)
            }
            InfoType.ACTIVE -> when {
                s.firstRun() -> brandedString(R.string.main_active_new)
                else -> brandedRandomString(R.array.main_active)
            }
            InfoType.DEACTIVATING -> brandedString(R.string.main_deactivating_new)
            InfoType.NOTIFICATIONS_DISABLED -> brandedString(R.string.notification_disabled)
            InfoType.NOTIFICATIONS_ENABLED -> brandedString(R.string.notification_enabled)
            InfoType.NOTIFICATIONS_KEEPALIVE_ENABLED -> brandedString(R.string.notification_keepalive_enabled)
            InfoType.NOTIFICATIONS_KEEPALIVE_DISABLED -> brandedString(R.string.notification_keepalive_disabled)
        }
    }

    private val enabledStateListener = object : IEnabledStateActorListener {

        override fun startDeactivating() {
            ui.infoQueue %= listOf(Info(InfoType.DEACTIVATING))
        }

        override fun finishDeactivating() {
            when {
                !s.enabled() -> ui.infoQueue %= listOf(Info(InfoType.PAUSED))
                s.restart() && s.connection().tethering ->
                    ui.infoQueue %= listOf(Info(InfoType.PAUSED_TETHERING))
                s.restart() && !s.connection().connected -> ui.infoQueue %= listOf(Info(InfoType.PAUSED_OFFLINE))
                else -> ui.infoQueue %= listOf(Info(InfoType.ERROR))
            }
        }

        override fun startActivating() {
            ui.infoQueue %= listOf(Info(InfoType.ACTIVATING))
        }

        override fun finishActivating() {
            ui.infoQueue %= listOf(Info(InfoType.ACTIVE))
        }

    }

    private fun brandedString(resId: Int): String {
        return getBrandedString(resId)
    }

    private fun brandedRandomString(resId: Int): String {
        return getRandomString(resId, R.string.branding_app_name_short)
    }

    companion object {
        var staticContext = Sync(WeakReference(null as Activity?))
        fun askPermissions() {
            val act = staticContext.get().get()
            if (act == null) {
//                Log.e("blokada", "Trying to start main activity")
//                val ctx: Context = globalKodein().instance()
//                val intent = Intent(ctx, MainActivity::class.java)
//                intent.putExtra("askPermissions", true)
//                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
//                ctx.startActivity(intent)
                throw Exception("starting MainActivity")
            }

            val task = startAskTunnelPermissions(act).promise.get()
            if (!task) { throw Exception("Could not get tunnel permissions") }
        }

//        fun share(id: String) {
//            val act = staticContext.get().get() ?: throw Status.exception("activity not started")
//            val intent = Intent(Intent.ACTION_SEND)
//            intent.type = "text/plain"
//            intent.putExtra(Intent.EXTRA_SUBJECT,
//                    act.getRandomString(R.array.viral_subject, R.string.branding_app_name))
//            intent.putExtra(Intent.EXTRA_TEXT,
//                    "http://play.google.com/store/apps/details?id=${act.packageName}&referrer=${id}")
//            act.startActivity(intent)
//        }
    }
}

