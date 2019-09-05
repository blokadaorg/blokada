package core

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.github.salomonbrys.kodein.*
import com.github.salomonbrys.kodein.Kodein.Module
import filter.DefaultSourceProvider
import gs.environment.Environment
import gs.environment.Worker
import gs.obsolete.hasCompleted
import gs.property.*
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.runBlocking
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import org.blokada.R
import tunnel.*
import tunnel.Persistence

abstract class Tunnel {
    abstract val enabled: IProperty<Boolean>
    abstract val error: IProperty<Boolean>
    abstract val retries: IProperty<Int>
    abstract val active: IProperty<Boolean>
    abstract val restart: IProperty<Boolean>
    abstract val updating: IProperty<Boolean>
    abstract val tunnelState: IProperty<TunnelState>
    abstract val tunnelPermission: IProperty<Boolean>
    abstract val tunnelDropCount: IProperty<Int>
    abstract val tunnelDropStart: IProperty<Long>
    abstract val tunnelRecentDropped: IProperty<List<String>>
    abstract val startOnBoot: IProperty<Boolean>
}

class TunnelImpl(
        kctx: Worker,
        private val xx: Environment,
        private val ctx: Context = xx().instance()
) : Tunnel() {


    override val enabled = newPersistedProperty(kctx, APrefsPersistence(ctx, "enabled"),
            { false }
    )

    override val error = newProperty(kctx, { false })

    override val active = newPersistedProperty(kctx, APrefsPersistence(ctx, "active"),
            { false }
    )

    override val restart = newPersistedProperty(kctx, APrefsPersistence(ctx, "restart"),
            { false }
    )

    override val retries = newProperty(kctx, { 3 })

    override val updating = newProperty(kctx, { false })

    override val tunnelState = newProperty(kctx, { TunnelState.INACTIVE })

    override val tunnelPermission = newProperty(kctx, {
        val (completed, _) = hasCompleted("tunnel:permission".ktx(),
                { checkTunnelPermissions(ctx.ktx("check perm")) })
        completed
    })

    override val tunnelDropCount = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelAdsCount"),
            { 0 }
    )

    override val tunnelDropStart = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelAdsStart"),
            { System.currentTimeMillis() }
    )

    override val tunnelRecentDropped = newProperty<List<String>>(kctx, { listOf() })

    override val startOnBoot  = newPersistedProperty(kctx, APrefsPersistence(ctx, "startOnBoot"),
            { true }
    )
}

fun newTunnelModule(ctx: Context): Module {
    return Module {
        bind<Tunnel>() with singleton { TunnelImpl(kctx = with("gscore").instance(), xx = lazy) }
        bind<IPermissionsAsker>() with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {
                    activityRegister.askPermissions()
                }
            }
        }
        bind<Main>() with singleton {
            val res: DefaultSourceProvider = instance()
            val tunnelState: Tunnel = instance()
            val f: Filters = instance()
            Main(
                onVpnClose = { ktx ->
                    tunnelState.tunnelPermission.refresh(blocking = true)
                    tunnelState.restart %= true
                    tunnelState.active %= false
                },
                onVpnConfigure = { ktx, vpn ->
                    vpn.setSession(ctx.getString(R.string.branding_app_name))
                        .setConfigureIntent(PendingIntent.getActivity(ctx, 1,
                                Intent(ctx, PanelActivity::class.java),
                                PendingIntent.FLAG_CANCEL_CURRENT))
                },
                onRequest = { request ->
                    if (request.blocked) {
                        tunnelState.tunnelDropCount %= tunnelState.tunnelDropCount() + 1
                        val dropped = tunnelState.tunnelRecentDropped() + request.domain
                        tunnelState.tunnelRecentDropped %= dropped.takeLast(10)
                    }

                    Persistence.request.save(request)
                },
                doResolveFilterSource = {
                    res.from(it.source.id, it.source.source)
                },
                doProcessFetchedFilters = {
                    f.apps.refresh(blocking = true)
                    it.map {
                        when {
                            it.source.id != "app" -> it
                            f.apps().firstOrNull { a -> a.appId == it.source.source } == null -> {
                                it.copy(hidden = true, active = false)
                            }
                            else -> it
                        }
                    }.toSet()
                }
        )  }
        onReady {
            val s: Tunnel = instance()
            val d: Device = instance()
            val dns: Dns = instance()
            val pages: Pages = instance()
            val device: Device = instance()
            val engine: tunnel.Main = instance()
            val perms: IPermissionsAsker = instance()
            val watchdog: IWatchdog = instance()
            val retryKctx: Worker = with("retry").instance()
            val ktx = "tunnel:legacy".ktx()
            var restarts = 0
            var lastRestartMillis = 0L

            dns.dnsServers.doWhenChanged(withInit = true).then {
                engine.setup(ctx.ktx("dns:changed"), dns.dnsServers())
            }

            async {
                ktx.on(BLOCKA_CONFIG) { cfg ->
                    engine.setup(ctx.ktx("blocka:vpn:switched"), dns.dnsServers(), cfg)

//                    if (cfg.blockaVpn && !s.enabled()) {
//                        ktx.v("auto activating on vpn gateway selected")
//                        s.enabled %= true
//                    }
                }

                ktx.on(Events.TUNNEL_RESTART) {
                    val restartedRecently = (System.currentTimeMillis() - lastRestartMillis) < 15 * 1000
                    lastRestartMillis = System.currentTimeMillis()
                    if (!restartedRecently) restarts = 0
                    if (restarts++ > 9 && device.watchdogOn()) {
                        restarts = 0
                        ktx.e("Too many tunnel restarts. Stopping...")
                        s.error %= true
                        s.enabled %= false
                    } else ktx.w("tunnel restarted for $restarts time in a row")
                }
            }

            var oldUrl = "localhost"
            pages.filters.doWhenSet().then {
                val url = pages.filters().toExternalForm()
                if (pages.filters().host != "localhost" && url != oldUrl) {
                    oldUrl = url
                    engine.setUrl(ctx.ktx("filtersUrl:changed"), url, d.onWifi())
                }
            }

            // React to user switching us off / on
            s.enabled.doWhenSet().then {
                s.restart %= s.enabled() && (s.restart() || d.isWaiting())
                s.active %= s.enabled() && !d.isWaiting()
            }

            // React to device power saving blocking our tunnel
            ktx.on(tunnel.Events.TUNNEL_POWER_SAVING) {
                ktx.w("power saving detected")
                ctx.startActivity(Intent(ctx, PowersaveActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            }

            // The tunnel setup routine (with permissions request)
            s.active.doWhenSet().then {
                ktx.e("enabled: ${s.enabled()}")
                if (s.enabled() && s.active() && s.tunnelState(TunnelState.INACTIVE)) {
                    s.retries %= s.retries() - 1
                    s.tunnelState %= TunnelState.ACTIVATING
                    s.tunnelPermission.refresh(blocking = true)
                    if (s.tunnelPermission(false)) {
                        hasCompleted(ktx, {
                            perms.askForPermissions()
                        })
                        s.tunnelPermission.refresh(blocking = true)
                    }

                    if (s.tunnelPermission(true)) {
                        val ktx = ctx.ktx("tunnel:start")
                        val (completed, err) = hasCompleted(ktx, { runBlocking {
                            engine.setup(ktx, dns.dnsServers(), start = true).await()
                        } })
                        if (completed) {
                            s.tunnelState %= TunnelState.ACTIVE
                        } else {
                            ktx.e("could not start tunnel", err ?: "no exception")
                        }
                    }

                    if (!s.tunnelState(TunnelState.ACTIVE)) {
                        s.tunnelState %= TunnelState.DEACTIVATING
                        hasCompleted(ktx, {
                            engine.stop(ctx.ktx("tunnel:stop:failStarting"))
                        })
                        s.tunnelState %= TunnelState.DEACTIVATED
                    }

                    s.updating %= false
                }
            }

            // Things that happen after we get everything set up nice and sweet
            var resetRetriesTask: Promise<*, *>? = null

            s.tunnelState.doWhenChanged().then {
                if (s.tunnelState(TunnelState.ACTIVE)) {
                    // Make sure the tunnel is actually usable by checking connectivity
                    if (d.screenOn()) watchdog.start()
                    if (resetRetriesTask != null) Kovenant.cancel(resetRetriesTask!!, Exception())

                    // Reset retry counter in case we seem to be stable
                    resetRetriesTask = task(retryKctx) {
                        if (s.tunnelState(TunnelState.ACTIVE)) {
                            Thread.sleep(15 * 1000)
                            ktx.v("tunnel stable")
                            if (s.tunnelState(TunnelState.ACTIVE)) s.retries.refresh()
                        }
                    }
                }
            }

            // Things that happen after we get the tunnel off
            s.tunnelState.doWhenChanged().then {
                if (s.tunnelState(TunnelState.DEACTIVATED)) {
                    s.active %= false
                    s.restart %= true
                    s.tunnelState %= TunnelState.INACTIVE
                    if (resetRetriesTask != null) Kovenant.cancel(resetRetriesTask!!, Exception())

                    // Monitor connectivity if disconnected, in case we can't relay on Android event
                    if (s.enabled() && d.screenOn()) watchdog.start()

                    // Reset retry counter after a longer break since we never give up, never surrender
                    resetRetriesTask = task(retryKctx) {
                        if (s.enabled() && s.retries(0) && !s.tunnelState(TunnelState.ACTIVE)) {
                            Thread.sleep(5 * 1000)
                            if (s.enabled() && !s.tunnelState(TunnelState.ACTIVE)) {
                                ktx.v("tunnel restart after wait")
                                s.retries.refresh()
                                s.restart %= true
                                s.tunnelState %= TunnelState.INACTIVE
                            }
                        }
                    }
                }
            }

            // Turn off the tunnel if disabled (by user, no connectivity, or giving up on error)
            s.active.doWhenChanged().then {
                if (s.active(false)
                        && s.tunnelState(TunnelState.ACTIVE, TunnelState.ACTIVATING)) {
                    watchdog.stop()
                    s.tunnelState %= TunnelState.DEACTIVATING
                    hasCompleted(ktx, {
                        engine.stop(ctx.ktx("tunnel:stop"))
                    })
                    s.tunnelState %= TunnelState.DEACTIVATED
                }
            }

            // Auto off in case of no connectivity, and auto on once connected
            d.connected.doWhenChanged(withInit = true).then {
                when {
                    !d.connected() && s.active() -> {
                        ktx.v("no connectivity, deactivating")
                        s.restart %= true
                        s.active %= false
                    }
                    d.connected() && s.restart() && !s.updating() && s.enabled() -> {
                        ktx.v("connectivity back, activating")
                        s.restart %= false
                        s.error %= false
                        s.active %= true
                    }
                    d.connected() && s.error() && !s.updating() && !s.enabled() -> {
                        ktx.v("connectivity back, auto recover from error")
                        s.error %= false
                        s.enabled %= true
                    }
                }
            }

            // Auto restart (eg. when reconfiguring the engine, or retrying)
            s.tunnelState.doWhen {
                s.tunnelState(TunnelState.INACTIVE) && s.enabled() && s.restart() && s.updating(false)
                        && !d.isWaiting() && s.retries() > 0
            }.then {
                ktx.v("tunnel auto restart")
                s.restart %= false
                s.active %= true
            }

            // Make sure watchdog is started and stopped as user wishes
            d.watchdogOn.doWhenChanged().then { when {
                d.watchdogOn() && s.tunnelState(TunnelState.ACTIVE, TunnelState.INACTIVE) -> {
                    // Flip the connected flag so we detect the change if now we're actually connected
                    d.connected %= false
                    watchdog.start()
                }
                d.watchdogOn(false) -> {
                    watchdog.stop()
                    d.connected.refresh()
                    d.onWifi.refresh()
                }
            }}

            // Monitor connectivity only when user is interacting with device
            d.screenOn.doWhenChanged().then { when {
                s.enabled(false) -> Unit
                d.screenOn() && s.tunnelState(TunnelState.ACTIVE, TunnelState.INACTIVE) -> watchdog.start()
                d.screenOn(false) -> watchdog.stop()
            }}

            s.startOnBoot {}

            d.onWifi.doWhenChanged().then {
                engine.reloadConfig(ctx.ktx("onWifi:changed"), d.onWifi())
            }

            async {
                registerTunnelConfigEvent(ktx)
                registerBlockaConfigEvent(ctx.ktx("blockaConfigInit"))

                engine.reloadConfig(ctx.ktx("load:persistence:after:start"), d.onWifi())
            }
        }
    }
}

enum class TunnelState {
    INACTIVE, ACTIVATING, ACTIVE, DEACTIVATING, DEACTIVATED
}

interface IPermissionsAsker {
    fun askForPermissions()
}

