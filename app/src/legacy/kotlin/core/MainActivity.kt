package core

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.support.design.widget.CoordinatorLayout
import android.support.v7.app.AppCompatActivity
import android.view.View
import android.widget.FrameLayout
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.LazyKodeinAware
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.ComponentProvider
import gs.environment.Journal
import gs.environment.Worker
import gs.environment.inject
import gs.presentation.isWrongInstance
import gs.property.Device
import gs.property.IWhen
import gs.property.Version
import io.codetail.widget.RevealFrameLayout
import nl.komponents.kovenant.task
import org.blokada.BuildConfig
import org.blokada.R
import tunnel.tunnelPermissionResult

class MainActivity : AppCompatActivity(), LazyKodeinAware {

    override val kodein = LazyKodein(inject)

    var landscape = false

    private var infoView: AInfoView? = null
    private var grid: AGridView? = null
    private var topBar: ATopBarView? = null
    private var contentActor: ContentActor? = null

    private val enabledStateActor: EnabledStateActor by instance()
    private val activityContext: ComponentProvider<Activity> by instance()
    private val activityProvider: ComponentProvider<MainActivity> by instance()
    private val j: Journal by instance()

    private val s: Filters by instance()
    private val t: Tunnel by instance()
    private val d: Device by instance()
    private val ui: UiState by instance()
    private val pages: Pages by instance()

    private val ictx: Worker by kodein.with("infotext").instance()
    private var currentlyDisplayed: InfoType? = null

    // TODO: less stuff in this class, more modules

    private var listener11: IWhen? = null
    private var listener12: IWhen? = null
    private var listener13: gs.property.IWhen? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        activityContext.set(this)
        activityProvider.set(this)

        if (isWrongInstance(this)) {
            finish()
            return
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

        val shadow = findViewById(R.id.info_shadow) as View
        shadow.visibility = if(landscape) View.INVISIBLE else View.VISIBLE

        ATopBarActor(
                xx = kodein,
                m = t,
                v = topBar!!,
                enabledStateActor = enabledStateActor,
                contentActor = contentActor!!,
                infoView = infoView!!,
                infoViewShadow = shadow,
                shadow = findViewById(R.id.shadow),
                window = window,
                ui = ui,
                pages = pages
        )

        grid = findViewById(R.id.grid) as AGridView
        grid?.ui = ui
        grid?.contentActor = contentActor

        val updateItems = {
                ui.dashes().filter(Dash::active)
        }

        grid?.items = updateItems()
        listener11 = ui.dashes.doOnUiWhenSet().then {
            grid?.items = updateItems()
        }

        grid?.onScrollToTop = { isTop ->
            if (!isTop && !landscape) topBar?.mode = ATopBarView.Mode.BAR
        }

        val fab = findViewById(R.id.fab) as AFloaterView
        AFabActor(fab, t, enabledStateActor, contentActor!!)

        if (landscape) {
            topBar?.mode = ATopBarView.Mode.BAR
            grid?.setPadding(0, 0, 0, 0)
            grid?.landscape = true
            grid?.adapter = grid?.adapter // To refresh grid
            val lp = fab.layoutParams as CoordinatorLayout.LayoutParams
            lp.gravity = android.view.Gravity.BOTTOM or android.view.Gravity.RIGHT
            fab.layoutParams = lp
        }

        activityRegister.register(this)

//        val d = AWelcomeDialog(this, contentActor!!)
//        listener13 = ui.seenWelcome.doOnUiWhenSet().then {
//            if (d.shouldShow()) d.show()
//        }

        val welcome: Welcome by instance()
        val version: Version by instance()
        val m = WelcomeDialogManager(kodein, BuildConfig.VERSION_CODE, {})
        m.run()
    }

    val activityResultListeners = mutableListOf({result: Int, data: Intent? -> })

    fun addOnNextActivityResultListener(listener: (result: Int, data: Intent?) -> Unit) {
        activityResultListeners.add(listener)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        activityResultListeners.forEach { it(resultCode, data) }
        activityResultListeners.clear()
        tunnelPermissionResult(Kontext.new("permission:vpn:result"), resultCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>,
                                            grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        storagePermissionResult(Kontext.new("permission:storage:result"), grantResults[0])
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        if (intent.getBooleanExtra("notification", false)) {
            val n: NotificationManager = inject().instance()
            n.cancel(1)
        }
        if (intent.getBooleanExtra("askPermissions", false)) {
            j.log("Started main activity for askForPermissions permissions")
            task {
                try {
                    activityRegister.askPermissions()
                } catch (e: Exception) {
                    t.active %= false
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
        enabledStateActor.update(t)
        infoQueueHandler(ui.infoQueue())
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onDestroy() {
//        staticContext.set(WeakReference(null as Activity?))
        super.onDestroy()
        activityContext.unset()
        activityProvider.unset()
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
            InfoType.ERROR -> brandedString(R.string.main_paused)
            InfoType.PAUSED -> brandedString(R.string.main_paused)
            InfoType.PAUSED_TETHERING -> brandedString(R.string.main_paused_autoenable_tethering)
            InfoType.PAUSED_OFFLINE -> brandedString(R.string.main_paused_autoenable)
            InfoType.ACTIVATING -> brandedString(R.string.main_loading)
            InfoType.ACTIVE -> brandedString(R.string.main_active)
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
                !t.enabled() -> ui.infoQueue %= listOf(Info(InfoType.PAUSED))
                t.restart() && d.tethering() ->
                    ui.infoQueue %= listOf(Info(InfoType.PAUSED_TETHERING))
                t.restart() && !d.connected() -> ui.infoQueue %= listOf(Info(InfoType.PAUSED_OFFLINE))
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

//    companion object {
//        var staticContext = Sync(WeakReference(null as Activity?))
//        fun askPermissions() {
//            val act = staticContext.get().get()
//            if (act == null) {
//                Log.e("blokada", "Trying to start main activity")
//                val ctx: Context = globalKodein().instance()
//                val intent = Intent(ctx, MainActivity::class.java)
//                intent.putExtra("askPermissions", true)
//                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
//                ctx.startActivity(intent)
//                throw Exception("starting MainActivity")
//            }
//
//            val deferred = askTunnelPermission(Kontext.new("static perm ask"), act)
//            runBlocking {
//                val response = deferred.await()
//                if (!response) { throw Exception("could not get tunnel permissions") }
//            }
//        }

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
//    }
}

fun Context.getBrandedString(resId: Int): String {
    return getString(resId, getString(R.string.branding_app_name_short))
}

