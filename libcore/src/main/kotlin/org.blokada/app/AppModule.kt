package org.blokada.app

import com.github.salomonbrys.kodein.*
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import org.blokada.app.android.AUpdateDownloader
import org.blokada.framework.*


fun newAppModule(): Kodein.Module {
    return Kodein.Module {
        // Kovenant context (one instance per prefix name)
        bind<KContext>() with multiton { it: String ->
            newSingleThreadedKContext(j = instance(), prefix = it)
        }
        bind<KContext>(10) with multiton { it: String ->
            newConcurrentKContext(j = instance(), prefix = it, tasks = 2)
        }
        // Probably should be somewhere else
        bind<EnabledStateActor>() with singleton {
            EnabledStateActor(this.lazy)
        }
        bind<UpdateCoordinator>() with singleton {
            UpdateCoordinator(s = instance(), downloader = AUpdateDownloader(ctx = instance()))
        }

        onReady {
            val s: State = instance()
            val j: IJournal = instance()
            val engine: IEngineManager = instance()
            val perms: IPermissionsAsker = instance()
            val watchdog: IWatchdog = instance()
            val retryKctx: KContext = with("retry").instance()

            // React to user switching us off / on
            s.enabled.doWhenChanged(withInit = true).then {
                s.restart %= s.enabled() && (s.restart() || s.connection().isWaiting())
                s.active %= s.enabled() && !s.connection().isWaiting()
            }

            // The tunnel setup routine (with permissions request)
            s.active.doWhenChanged(withInit = true).then {
                if (s.active() && s.tunnelState(TunnelState.INACTIVE)) {
                    s.retries %= s.retries() - 1
                    s.tunnelState %= TunnelState.ACTIVATING
                    s.tunnelPermission.refresh(blocking = true)
                    if (s.tunnelPermission(false)) {
                        hasCompleted(j, {
                            if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_ASK_VPN)
                            perms.askForPermissions()
                        })
                        s.tunnelPermission.refresh(blocking = true)
                    }

                    if (s.tunnelPermission(true)) {
                        val (completed, err) = hasCompleted(null, { engine.start() })
                        if (completed) {
                            s.tunnelState %= TunnelState.ACTIVE
                        } else {
                            j.log(Exception("could not activate: ${err}"))
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
                    if (s.screenOn()) watchdog.start()
                    if (resetRetriesTask != null) Kovenant.cancel(resetRetriesTask!!, Exception())

                    // Reset retry counter in case we seem to be stable
                    resetRetriesTask = task(retryKctx) {
                        if (s.tunnelState(TunnelState.ACTIVE)) {
                            Thread.sleep(15 * 1000)
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
                    if (s.enabled() && s.screenOn()) watchdog.start()

                    // Reset retry counter after a longer break since we never give up, never surrender
                    resetRetriesTask = task(retryKctx) {
                        if (s.enabled() && s.retries(0) && !s.tunnelState(TunnelState.ACTIVE)) {
                            Thread.sleep(30 * 1000)
                            if (s.enabled() && !s.tunnelState(TunnelState.ACTIVE)) {
                                j.log("restart after long wait")
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

            // Auto off in case of no connectivity or tethering enabled, and auto on once connected
            s.connection.doWhenChanged(withInit = true).then {
                val c = s.connection()
                when {
                    !c.connected && s.active() -> {
                        s.restart %= true
                        s.active %= false
                    }
                    c.connected && c.tethering && s.active() -> {
                        s.restart %= true
                        s.active %= false
                    }
                    c.connected && !c.tethering && s.restart() && !s.updating() && s.enabled() -> {
                        s.restart %= false
                        s.active %= true
                    }
                }
            }

            // Auto restart (eg. when reconfiguring the engine, or retrying)
            s.tunnelState.doWhen {
                s.tunnelState(TunnelState.INACTIVE) && s.enabled() && s.restart() && s.updating(false)
                        && !s.connection().isWaiting() && s.retries() > 0
            }.then {
                // Do last retry without the watchdog in case it doesn't work on this device
                if (s.retries() == 1) s.watchdogOn %= false
                j.log("restart. watchdog ${s.watchdogOn()}")

                s.restart %= false
                s.active %= true
            }

            // Monitor connectivity only when user is interacting with device
            s.screenOn.doWhenChanged().then { when {
                s.enabled(false) -> Unit
                s.screenOn() && s.tunnelState(TunnelState.ACTIVE, TunnelState.INACTIVE) -> watchdog.start()
                s.screenOn(false) -> watchdog.stop()
            }}

            // Make sure watchdog is started and stopped as user wishes
            s.watchdogOn.doWhenChanged().then { when {
                s.watchdogOn() && s.tunnelState(TunnelState.ACTIVE, TunnelState.INACTIVE) -> {
                    // Flip the connected flag so we detect the change if now we're actually connected
                    s.connection %= Connection(
                            connected = false,
                            tethering = s.connection().tethering,
                            dnsServers = s.connection().dnsServers
                    )
                    watchdog.start()
                }
                s.watchdogOn(false) -> {
                    watchdog.stop()
                    s.connection.refresh()
                }
            }}

            // Make sure always supported engine is selected
            s.tunnelActiveEngine.doWhenChanged().then {
                var selected = s.tunnelEngines().firstOrNull { it.id == s.tunnelActiveEngine() }
                if (!(selected?.supported ?: false)) {
                    // Selection is invalid, update it to whichever first engine is supported
                    selected = s.tunnelEngines().first { it.supported }
                }

                // Reload the engine to use the new one
                if (!s.enabled()) {
                } else if (s.active()) {
                    s.restart %= true
                    s.active %= false
                } else {
                    s.retries.refresh()
                    s.restart %= false
                    s.active %= true
                }
                j.setUserProperty(Properties.ENGINE_ACTIVE, s.tunnelActiveEngine())

                s.tunnelActiveEngine %= selected!!.id
            }

            // Compile filters every time they change
            s.filters.doWhenSet().then {
                s.filtersCompiled.refresh(force = true)
            }

            // Push filters to engine every time they're changed
            s.filtersCompiled.doWhenSet().then {
                engine.updateFilters()
            }

            // Check for update periodically
            s.tunnelState.doWhen { s.tunnelState(TunnelState.ACTIVE) }.then {
                // This "pokes" the cache and refreshes if needed
                s.repo.refresh()
                s.filters.refresh()
            }

            // Since having filters is really important, poke whenever we get connectivity
            var wasConnected = false
            s.connection.doWhenChanged().then {
                if (s.connection().connected && !wasConnected) s.repo.refresh()
                wasConnected = s.connection().connected
            }

            s.repo.doWhenChanged(withInit = true).then {
                s.localised.refresh(force = true)
            }

            // On locale change, refresh all localised content
            s.localised.doWhenChanged(withInit = true).then {
                s.filters.refresh(force = true)
            }

            // Report enabled property and first activation started event
            s.enabled.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.ENABLED, s.enabled())
                if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_START)
            }

            // Report tunnel_state property
            s.tunnelState.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.TUNNEL_STATE, s.tunnelState)
            }

            // Report watchdog property
            s.watchdogOn.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.WATCHDOG, s.watchdogOn)
            }

            // Report first activation successfuly finished event
            s.tunnelState.doWhen { s.tunnelState(TunnelState.ACTIVE) && s.firstRun(true) }.then {
                j.event(Events.FIRST_ACTIVE_FINISH)
            }

            // Report start on boot property
            s.startOnBoot.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.AUTO_START, s.startOnBoot())
            }
        }
    }
}

