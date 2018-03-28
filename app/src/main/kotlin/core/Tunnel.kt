package core

import android.content.Context
import com.github.salomonbrys.kodein.*
import com.github.salomonbrys.kodein.Kodein.Module
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.environment.inject
import gs.obsolete.hasCompleted
import gs.property.*
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import tunnel.checkTunnelPermissions

abstract class Tunnel {
    abstract val enabled: IProperty<Boolean>
    abstract val retries: IProperty<Int>
    abstract val active: IProperty<Boolean>
    abstract val restart: IProperty<Boolean>
    abstract val updating: IProperty<Boolean>
    abstract val tunnelState: IProperty<TunnelState>
    abstract val tunnelPermission: IProperty<Boolean>
    abstract val tunnelDropCount: IProperty<Int>
    abstract val tunnelRecentDropped: IProperty<List<String>>
    abstract val tunnelConfig: IProperty<TunnelConfig>
    abstract val startOnBoot: IProperty<Boolean>
}

class TunnelImpl(
        kctx: Worker,
        private val xx: Environment,
        private val ctx: Context = xx().instance()
) : Tunnel() {

    override val tunnelConfig = newProperty<TunnelConfig>(kctx, { ctx.inject().instance() })

    override val enabled = newPersistedProperty(kctx, APrefsPersistence(ctx, "enabled"),
            { false }
    )

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
        val (completed, _) = hasCompleted(null, { checkTunnelPermissions(ctx) })
        completed
    })

    override val tunnelDropCount = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelAdsCount"),
            { 0 }
    )

    override val tunnelRecentDropped = newProperty<List<String>>(kctx, { listOf() })

    override val startOnBoot  = newPersistedProperty(kctx, APrefsPersistence(ctx, "startOnBoot"),
            { true }
    )

}

fun newTunnelModule(ctx: Context): Module {
    return Module {
        bind<Tunnel>() with singleton { TunnelImpl(kctx = with("gscore").instance(), xx = lazy) }
        bind<TunnelConfig>() with singleton { TunnelConfig(defaultEngine = "lollipop") }
        bind<IPermissionsAsker>() with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {
                    MainActivity.askPermissions()
                }
            }
        }
        onReady {
            val s: Tunnel = instance()
            val d: Device = instance()
            val j: Journal = instance()
            val engine: IEngineManager = instance()
            val perms: IPermissionsAsker = instance()
            val watchdog: IWatchdog = instance()
            val retryKctx: Worker = with("retry").instance()

            // todo: refresh watchdog on connection change (or)
            // React to user switching us off / on
            s.enabled.doWhenChanged(withInit = true).then {
                s.restart %= s.enabled() && (s.restart() || d.isWaiting())
                s.active %= s.enabled() && !d.isWaiting()
            }

            // The tunnel setup routine (with permissions request)
            s.active.doWhenChanged(withInit = true).then {
                if (s.active() && s.tunnelState(TunnelState.INACTIVE)) {
                    s.retries %= s.retries() - 1
                    s.tunnelState %= TunnelState.ACTIVATING
                    s.tunnelPermission.refresh(blocking = true)
                    if (s.tunnelPermission(false)) {
                        hasCompleted(j, {
                            perms.askForPermissions()
                        })
                        s.tunnelPermission.refresh(blocking = true)
                    }

                    if (s.tunnelPermission(true)) {
                        val (completed, err) = hasCompleted(null, { engine.start() })
                        if (completed) {
                            s.tunnelState %= TunnelState.ACTIVE
                        } else {
                            j.log(Exception("tunnel: could not activate", err))
                        }
                    }

                    if (!s.tunnelState(TunnelState.ACTIVE)) {
                        s.tunnelState %= TunnelState.DEACTIVATING
                        hasCompleted(j, { engine.stop() })
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
                            j.log("tunnel: stable")
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
                                j.log("tunnel: restart after wait")
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
                    hasCompleted(j, { engine.stop() })
                    s.tunnelState %= TunnelState.DEACTIVATED
                }
            }

            // Auto off in case of no connectivity, and auto on once connected
            d.connected.doWhenChanged(withInit = true).then {
                when {
                    !d.connected() && s.active() -> {
                        j.log("tunnel: no connectivity, deactivating")
                        s.restart %= true
                        s.active %= false
                    }
                    d.connected() && s.restart() && !s.updating() && s.enabled() -> {
                        j.log("tunnel: connectivity back, activating")
                        s.restart %= false
                        s.active %= true
                    }
                }
            }

            // Auto restart (eg. when reconfiguring the engine, or retrying)
            s.tunnelState.doWhen {
                s.tunnelState(TunnelState.INACTIVE) && s.enabled() && s.restart() && s.updating(false)
                        && !d.isWaiting() && s.retries() > 0
            }.then {
                j.log("tunnel: auto restart")
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
                }
            }}

            // Monitor connectivity only when user is interacting with device
            d.screenOn.doWhenChanged().then { when {
                s.enabled(false) -> Unit
                d.screenOn() && s.tunnelState(TunnelState.ACTIVE, TunnelState.INACTIVE) -> watchdog.start()
                d.screenOn(false) -> watchdog.stop()
            }}

            s.startOnBoot {}
        }
    }
}

enum class TunnelState {
    INACTIVE, ACTIVATING, ACTIVE, DEACTIVATING, DEACTIVATED
}

open class Engine (
        val id: String,
        val supported: Boolean = true,
        val recommended: Boolean = false,
        val createIEngineManager: (e: EngineEvents) -> IEngineManager
)

data class EngineEvents (
        val adBlocked: (String) -> Unit = {},
        val error: (String) -> Unit = {},
        val onRevoked: () -> Unit = {}
)

data class TunnelConfig(
        val defaultEngine: String
)

interface IEngineManager {
    fun start()
    fun updateFilters()
    fun stop()
}

interface IPermissionsAsker {
    fun askForPermissions()
}

