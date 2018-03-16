package core

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.util.Log
import com.github.salomonbrys.kodein.*
import filter.*
import gs.environment.ActivityProvider
import gs.environment.Journal
import gs.environment.Time
import gs.obsolete.hasCompleted
import gs.property.*
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import notification.createNotificationKeepAlive
import notification.displayNotificationForUpdate
import org.blokada.BuildConfig
import org.blokada.R
import org.obsolete.IWhen
import org.obsolete.KContext
import tunnel.ATunnelAgent
import tunnel.AWatchdog
import update.AUpdateDownloader
import update.UpdateCoordinator
import update.isUpdate
import java.io.File
import java.net.URL


fun newAppModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<EnabledStateActor>() with singleton {
            EnabledStateActor(this.lazy)
        }
        bind<UpdateCoordinator>() with singleton {
            UpdateCoordinator(s = instance(), downloader = AUpdateDownloader(ctx = instance()))
        }

        bind<State>() with singleton { AState(kctx = with("gscore").instance(10), xx = lazy,
                ctx = ctx) }
        bind<UiState>() with singleton { AUiState(kctx = with("gscore").instance(10), xx = lazy) }

        bind<ActivityProvider<Activity>>() with singleton { ActivityProvider<Activity>() }
        bind<ActivityProvider<MainActivity>>() with singleton { ActivityProvider<MainActivity>() }

        bind<AFilterAddDialog>() with provider {
            AFilterAddDialog(ctx,
                    sourceProvider = { type: String -> with(type).instance<IFilterSource>() }
            )
        }
        bind<AFilterGenerateDialog>(true) with provider {
            AFilterGenerateDialog(ctx,
                    s = instance(),
                    sourceProvider = { type: String -> with(type).instance<IFilterSource>() },
                    whitelist = true
            )
        }
        bind<AFilterGenerateDialog>(false) with provider {
            AFilterGenerateDialog(ctx,
                    s = instance(),
                    sourceProvider = { type: String -> with(type).instance<IFilterSource>() },
                    whitelist = false
            )
        }

        // Various components
        bind<AConnectivityReceiver>() with singleton { AConnectivityReceiver() }
        bind<AScreenOnReceiver>() with singleton { AScreenOnReceiver() }
        bind<ALocaleReceiver>() with singleton { ALocaleReceiver() }
        bind<ATunnelAgent>() with singleton { ATunnelAgent(ctx) }
        bind<IWatchdog>() with singleton { AWatchdog(ctx) }
        bind<IHostlineProcessor>() with singleton { DefaultHostlineProcessor() }
        bind<IFilterSource>() with factory { sourceId: String ->
            val cfg: FilterConfig = instance()
            val processor: IHostlineProcessor = instance()

            when (sourceId) {
                "link" -> FilterSourceLink(cfg.fetchTimeoutMillis, processor)
                "file" -> FilterSourceUri(ctx = instance(), processor = instance())
                "app" -> FilterSourceApp(ctx = instance())
                else -> FilterSourceSingle()
            }}
        bind<FilterSerializer>() with singleton {
            FilterSerializer(i18n = instance(),
                    sourceProvider = { type: String -> with(type).instance<IFilterSource>() })
        }
        bind<FilterConfig>() with singleton {
            FilterConfig(
                    cacheFile = File(getPersistencePath(ctx).absoluteFile, "filters"),
                    exportFile = getPublicPersistencePath("blokada-export")
                            ?: File(getPersistencePath(ctx).absoluteFile, "blokada-export"),
                    cacheTTLMillis = 1 * 24 * 60 * 60 * 100L, // A
                    fetchTimeoutMillis = 10 * 1000
            )
        }
        bind<TunnelConfig>() with singleton { TunnelConfig(defaultEngine = "lollipop") }
        bind<IPermissionsAsker>() with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {
                    MainActivity.askPermissions()
                }
            }
        }
        bind<Pages>() with singleton {
            PagesImpl(with("gscore").instance(), lazy)
        }
        bind<Dns>() with singleton {
            DnsImpl(with("gscore").instance(), lazy)
        }
        bind<DnsLocalisedFetcher>() with singleton {
            DnsLocalisedFetcher(xx = lazy)
        }
        bind<Welcome>() with singleton {
            WelcomeImpl(w = with("gscore").instance(2), xx = lazy)
        }

        onReady {
            val s: State = instance()
            val j: Journal = instance()
            val engine: IEngineManager = instance()
            val perms: IPermissionsAsker = instance()
            val watchdog: IWatchdog = instance()
            val retryKctx: KContext = with("gscore").instance()

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
                        if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_START)
                        val (completed, err) = hasCompleted(null, { engine.start() })
                        if (completed) {
                            s.tunnelState %= TunnelState.ACTIVE
                        } else {
                            j.log(Exception("could not activate: ${err}"))
                            if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_FAIL)
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
                            Thread.sleep(5 * 1000)
                            if (s.enabled() && !s.tunnelState(TunnelState.ACTIVE)) {
                                j.log("restart after long wait")
                                s.retries.refresh()
                                s.restart %= true
                                s.tunnelState %= TunnelState.INACTIVE
                            } else if (s.enabled() && s.firstRun()) {
                                j.event(Events.FIRST_ACTIVE_FINISH)
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
            s.connection.doWhenChanged(withInit = true).then {
                val c = s.connection()
                when {
                    !c.connected && s.active() -> {
                        s.restart %= true
                        s.active %= false
                    }
                    c.connected && s.restart() && !s.updating() && s.enabled() -> {
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

            // Reload engine in case whitelisted apps selection changes
            var currentApps = listOf<Filter>()
            s.filters.doWhenSet().then {
                val newApps = s.filters().filter { it.whitelist && it.active && it.source is FilterSourceApp }
                if (newApps != currentApps) {
                    currentApps = newApps

                    if (!s.enabled()) {
                    } else if (s.active()) {
                        s.restart %= true
                        s.active %= false
                    } else {
                        s.retries.refresh()
                        s.restart %= false
                        s.active %= true
                    }
                }
            }

            // Reload engine in case dns selection changes
            val dns: Dns = instance()
            var currentDns: DnsChoice? = null
            dns.choices.doWhenSet().then {
                val newChoice = dns.choices().firstOrNull { it.active }
                if (newChoice != null && newChoice != currentDns) {
                    currentDns = newChoice

                    if (!s.enabled()) {
                    } else if (s.active()) {
                        s.restart %= true
                        s.active %= false
                    } else {
                        s.retries.refresh()
                        s.restart %= false
                        s.active %= true
                    }
                }
            }

            // Compile filters every time they change
            s.filters.doWhenSet().then {
                s.filtersCompiled.refresh(force = true)
            }

            // Push filters to engine every time they're changed
            s.filtersCompiled.doWhenSet().then {
                engine.updateFilters()
            }

            val repo: Repo = instance()

            // Check for update periodically
            s.tunnelState.doWhen { s.tunnelState(TunnelState.ACTIVE) }.then {
                // This "pokes" the cache and refreshes if needed
                repo.content.refresh()
                s.filters.refresh()
            }

            // Since having filters is really important, poke whenever we get connectivity
            var wasConnected = false
            s.connection.doWhenChanged().then {
                if (s.connection().connected && !wasConnected) repo.content.refresh()
                wasConnected = s.connection().connected
            }

            val welcome: Welcome = instance()
            welcome.conflictingBuilds %= listOf("org.blokada.origin.alarm", "org.blokada.alarm", "org.blokada", "org.blokada.dev")
            welcome.obsoleteUrl %= URL("https://blokada.org/api/legacy/content/root/obsolete.html")

            // On locale change, refresh all localised content
            val i18n: I18n = instance()

            i18n.locale.doWhenSet().then {
                val root = i18n.contentUrl()
                welcome.updatedUrl %= URL("${root}/updated.html")
                welcome.cleanupUrl %= URL("${root}/cleanup.html")
                welcome.ctaUrl %= URL("${root}/cta.html")
                welcome.patronShow %= true
                // Last one because it triggers dialogs
                welcome.introUrl %= URL("${root}/intro.html")
            }

            i18n.locale.doWhenChanged().then {
                Log.i("blokada", "refresh filters from locale change")
                s.filters.refresh(force = true)
            }

            // Report enabled property and first activation started event
            s.enabled.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.ENABLED, s.enabled())
            }

            // Report tunnel_state property
            s.tunnelState.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.TUNNEL_STATE, s.tunnelState)
            }

            // Report watchdog property
            s.watchdogOn.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.WATCHDOG, s.watchdogOn)
            }

            // Report start on boot property
            s.startOnBoot.doWhenChanged(withInit = true).then {
                j.setUserProperty(Properties.AUTO_START, s.startOnBoot())
            }


            val version: Version = instance()
            version.appName %= ctx.getString(R.string.branding_app_name)
            version.name %= BuildConfig.VERSION_NAME

            val ui: UiState = instance()

            // Show confirmation message whenever keepAlive configuration is changed
            s.keepAlive.doWhenChanged().then {
                if (s.keepAlive()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_DISABLED)
                }
            }

            // Report user property for keepAlive
            s.keepAlive.doWhenSet().then {
                j.setUserProperty(Properties.KEEP_ALIVE, s.keepAlive())
            }

            // Persist dashes whenever done editing
            ui.editUi.doWhen { ui.editUi(false) }.then {
                ui.dashes %= ui.dashes()
            }

            // Start / stop the keep alive service depending on the configuration flag
            val keepAliveNotificationUpdater = { dropped: Int ->
                val ctx: Context = instance()
                val nm: NotificationManager = instance()
                val n = createNotificationKeepAlive(ctx = ctx, count = dropped,
                        last = s.tunnelRecentDropped().lastOrNull() ?:
                        ctx.getString(R.string.notification_keepalive_none)
                )
                nm.notify(3, n)
            }
            var w: IWhen? = null
            s.keepAlive.doWhenSet().then {
                if (s.keepAlive()) {
                    s.tunnelDropCount.cancel(w)
                    w = s.tunnelDropCount.doOnUiWhenSet().then {
                        keepAliveNotificationUpdater(s.tunnelDropCount())
                    }
                    keepAliveAgent.bind(ctx)
                } else {
                    s.tunnelDropCount.cancel(w)
                    keepAliveAgent.unbind(ctx)
                }
            }

            // Display an info message when update is available
            repo.content.doOnUiWhenSet().then {
                if (isUpdate(ctx, repo.content().newestVersionCode)) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, R.string.update_infotext)
                    ui.lastSeenUpdateMillis.refresh(force = true)
                }
            }

            // Display notifications for updates
            ui.lastSeenUpdateMillis.doOnUiWhenSet().then {
                val u = repo.content()
                val last = ui.lastSeenUpdateMillis()
                val cooldown = 86400 * 1000L
                val env: Time = instance()
                val j: Journal = instance()

                if (isUpdate(ctx, u.newestVersionCode) && canShowNotification(last, env, cooldown)) {
                    displayNotificationForUpdate(ctx, u.newestVersionName)
                    ui.lastSeenUpdateMillis %= env.now()
                    j.event(Events.UPDATE_NOTIFY)
                }
            }

            // Refresh filters list whenever system apps switch is changed
            ui.showSystemApps.doWhenChanged().then {
                s.filters %= s.filters()
            }

            // Register various Android listeners to receive events
            task {
                // In a task because we are in DI and using DI can lead to stack overflow
                AConnectivityReceiver.register(ctx)
                AScreenOnReceiver.register(ctx)
                ALocaleReceiver.register(ctx)
            }

            // Initialize default values for properties that need it (async)
            s.startOnBoot {}
            s.keepAlive {}
            s.filtersCompiled {}

            // This will fetch repo unless already cached
            repo.url %= "https://blokada.org/api/${BuildConfig.VERSION_CODE}/${BuildConfig.FLAVOR}/${BuildConfig.BUILD_TYPE}/repo.txt"
        }
    }
}

// So that it's never GC'd, not sure if it actually does anything
private val keepAliveAgent by lazy { KeepAliveAgent() }
