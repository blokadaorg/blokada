package org.blokada.app

import com.github.salomonbrys.kodein.*
import org.blokada.app.android.AUpdateDownloader
import org.blokada.framework.*


fun newAppModule(): Kodein.Module {
    return Kodein.Module {
        // Kovenant context (one instance per prefix name)
        bind<KContext>() with multiton { it: String ->
            newSingleThreadedKContext(j = instance(), prefix = it)
        }
        bind<KContext>(10) with multiton { it: String ->
            newConcurrentKContext(j = instance(), prefix = it, tasks = 1)
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

            // Auto off/on in case of no connectivity or tethering enabled
            s.connection.doWhenSet().then {
                val c = s.connection()
                when {
                    !c.connected && s.enabled() -> {
                        s.restart %= true
                        s.enabled %= false
                    }
                    c.connected && c.tethering && s.enabled() -> {
                        s.restart %= true
                        s.enabled %= false
                    }
                    c.connected && !c.tethering && s.restart() && !s.updating() -> {
                        s.restart %= false
                        s.enabled %= true
                    }
                }
            }

            // The tunnel setup routine (with permissions request)
            s.enabled.doWhen {
                s.enabled(true)
                        && s.tunnelState(TunnelState.INACTIVE, TunnelState.DEACTIVATING)
            }.then {
                var attempts = 3
                s.tunnelState %= TunnelState.ACTIVATING
                while (attempts-- > 0 && !s.tunnelState(TunnelState.ACTIVE)) {
                    s.tunnelPermission.refresh(blocking = true)
                    if (s.tunnelPermission(false)) {
                        hasCompleted {
                            if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_ASK_VPN)
                            perms.askForPermissions()
                        }
                        s.tunnelPermission.refresh(blocking = true)
                    }

                    if (s.tunnelPermission(true)) {
                        if (hasCompleted { engine.start() }) {
                            s.tunnelState %= TunnelState.ACTIVE
                        } else {
                            hasCompleted { engine.stop() }
                            s.tunnelState %= TunnelState.FAILED
                        }
                    }
                }

                if (!s.tunnelState(TunnelState.ACTIVE)) {
                    s.tunnelState %= TunnelState.DEACTIVATING
                    hasCompleted { engine.stop() }
                    s.tunnelState %= TunnelState.INACTIVE
                    s.enabled %= false
                }

                s.updating %= false
            }

            // Turn off the tunnel if disabled (by user, or giving up on error)
            s.enabled.doWhenChanged().then {
                if (s.enabled(false)
                        && s.tunnelState(TunnelState.ACTIVE, TunnelState.ACTIVATING)) {
                    s.tunnelState %= TunnelState.DEACTIVATING
                    hasCompleted { engine.stop() }
                    s.tunnelState %= TunnelState.INACTIVE
                }
            }

            // Auto restart (eg. when reconfiguring the engine)
            s.tunnelState.doWhen {
                s.tunnelState(TunnelState.INACTIVE) && s.restart(true) && s.updating(false)
                        && s.connection().connected && !s.connection().tethering
            }.then {
                s.enabled %= true
                s.restart %= false
            }

            // Make sure always supported engine is selected
            s.tunnelActiveEngine.doWhenChanged(withInit = true).then {
                var selected = s.tunnelEngines().firstOrNull { it.id == s.tunnelActiveEngine() }
                if (!(selected?.supported ?: false)) {
                    // Selection is invalid, update it to whichever first engine is supported
                    selected = s.tunnelEngines().first { it.supported }
                }

                // Reload the engine to use the new one
                if (s.enabled() && s.tunnelState(TunnelState.ACTIVE)) {
                    s.restart %= true
                    s.enabled %= false
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

            // On locale change, refresh all localised content
            s.localised.doWhenChanged().then {
                s.filters.refresh(force = true)
            }

            // Report enabled property and first activation started event
            s.enabled.doWhenSet().then {
                j.setUserProperty(Properties.ENABLED, s.enabled())
                if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_START)
            }

            // Report first activation successfuly finished event
            s.tunnelState.doWhen { s.tunnelState(TunnelState.ACTIVE) && s.firstRun(true) }.then {
                j.event(Events.FIRST_ACTIVE_FINISH)
            }

            // Report first activation failed event
            s.tunnelState.doWhen { s.tunnelState(TunnelState.FAILED) && s.firstRun(true) }.then {
                j.event(Events.FIRST_ACTIVE_FAIL)
            }

            // Report start on boot property
            s.startOnBoot.doWhenSet().then {
                j.setUserProperty(Properties.AUTO_START, s.startOnBoot())
            }
        }
    }
}

