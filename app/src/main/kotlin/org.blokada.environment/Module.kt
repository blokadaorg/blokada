package org.blokada.environment

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import com.github.salomonbrys.kodein.*
import gs.environment.ActivityProvider
import gs.environment.Journal
import gs.environment.Time
import gs.property.Version
import gs.property.Welcome
import gs.property.WelcomeImpl
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import org.obsolete.*
import org.blokada.BuildConfig
import org.blokada.R
import org.blokada.main.*
import org.blokada.presentation.*
import org.blokada.property.*
import org.blokada.property.Info
import org.blokada.property.InfoType
import org.blokada.property.UiState
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

        bind<State>() with singleton { AState(ctx, kctx = with("state").instance(10)) }
        bind<UiState>() with singleton { AUiState(ctx, kctx = with("uistate").instance(10)) }

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

        // EngineManager that can switch between concrete engines
        bind<IEngineManager>() with singleton {
            val s: State = instance()
            val j: Journal = instance()

            AEngineManagerProvider(s,
                    adBlocked = { host ->
                        s.tunnelAdsCount %= s.tunnelAdsCount() + 1
                        val ads = s.tunnelRecentAds() + host
                        s.tunnelRecentAds %= ads.takeLast(10)
                        j.event(Events.AD_BLOCKED(host))
                        if (s.firstRun(true)) {
                            j.event(Events.FIRST_AD_BLOCKED)
                            s.firstRun %= false
                        }
                    },
                    error = {
                        if (s.firstRun(true)) j.event(Events.FIRST_ACTIVE_FAIL)
                        j.log(Exception("engine error while running: $it"))

                        // Reload the engine and hope now it works
                        if (s.active()) {
                            s.restart %= true
                            s.active %= false
                        }
                    },
                    onRevoked = {
                        s.tunnelPermission.refresh(blocking = true)
                        s.restart %= true
                        s.active %= false
                    }
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
            FilterSerializer(s = instance(),
                    sourceProvider = { type: String -> with(type).instance<IFilterSource>() })
        }
        bind<FilterConfig>() with singleton {
            FilterConfig(
                    cacheFile = File(getPersistencePath(ctx).absoluteFile, "filters"),
                    exportFile = getPublicPersistencePath("blokada-export")
                            ?: File(getPersistencePath(ctx).absoluteFile, "blokada-export"),
                    cacheTTLMillis = 7 * 24 * 60 * 60 * 100L, // A week
                    repoURL = URL("http://blokada.org/api/${BuildConfig.VERSION_CODE}/${BuildConfig.FLAVOR}/filters.txt"),
                    fetchTimeoutMillis = 10 * 1000
            )
        }
        bind<RepoConfig>() with singleton {
            RepoConfig(
                    cacheFile = File(getPersistencePath(ctx).absoluteFile, "repo"),
                    cacheTTLMillis = 24 * 60 * 60 * 1000L, // A day
                    repoURL = URL("http://blokada.org/api/${BuildConfig.VERSION_CODE}/${BuildConfig.FLAVOR}/repo.txt"),
                    fetchTimeoutMillis = 10 * 1000,
                    notificationCooldownMillis = 24 * 60 * 60 * 1000L // A day
            )
        }
        bind<VersionConfig>() with singleton {
            VersionConfig(
                    appName = ctx.getString(R.string.branding_app_name),
                    appVersion = BuildConfig.VERSION_NAME,
                    appVersionCode = BuildConfig.VERSION_CODE,
                    coreVersion = BuildConfig.VERSION_NAME,
                    uiVersion = BuildConfig.VERSION_NAME
            )
        }
        bind<TunnelConfig>() with singleton { TunnelConfig(defaultEngine = "lollipop") }
        bind<List<Engine>>() with singleton { listOf(Engine(
                id = "lollipop",
                createIEngineManager = {
                    ALollipopEngineManager(ctx,
                            agent = instance(),
                            adBlocked = it.adBlocked,
                            error = it.error,
                            onRevoked = it.onRevoked
                    )
                }
        )) }
        bind<IPermissionsAsker>() with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {
                    MainActivity.askPermissions()
                }
            }
        }
        bind<ATunnelService.IBuilderConfigurator>() with singleton {
            object : ATunnelService.IBuilderConfigurator {
                override fun configure(builder: VpnService.Builder) {
                    builder.setSession(ctx.getString(R.string.branding_app_name))
                            .setConfigureIntent(PendingIntent.getActivity(ctx, 1,
                                    Intent(ctx, MainActivity::class.java),
                                    PendingIntent.FLAG_CANCEL_CURRENT))
                }
            }
        }
        bind<Welcome>() with singleton {
            WelcomeImpl(w = with("welcome").instance(), xx = instance())
        }


        onReady {
            val s: State = instance()
            val j: Journal = instance()
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
                            Thread.sleep(30 * 1000)
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


            s.localised.doWhenChanged(withInit = true).then {
                val root = s.localised().content
                val welcome: Welcome = instance()
                welcome.introUrl %= URL("${root}/intro.html")
                welcome.guideUrl %= URL("${root}/help.html")
                welcome.optionalUrl %= URL("${root}/patron_redirect.html")
                welcome.updatedUrl %= URL("${root}/updated.html")
                welcome.obsoleteUrl %= URL("${root}/obsolete.html")
                welcome.cleanupUrl %= URL("${root}/cleanup.html")
                welcome.optionalShow %= true
            }

            val version: Version = instance()
            version.appName %= ctx.getString(R.string.branding_app_name)
            version.name %= BuildConfig.VERSION_NAME

            val ui: UiState = instance()

            // Show confirmation message to the user whenever notifications are enabled or disabled
            ui.notifications.doWhenChanged().then {
                if (ui.notifications()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_DISABLED)
                }
            }

            // Show confirmation message whenever keepAlive configuration is changed
            s.keepAlive.doWhenChanged().then {
                if (s.keepAlive()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_DISABLED)
                }
            }

            // Report user property for notifications
            ui.notifications.doWhenSet().then {
                j.setUserProperty(Properties.NOTIFICATIONS, ui.notifications())
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
            val keepAliveNotificationUpdater = { adsBlocked: Int ->
                displayNotificationKeepAlive(ctx = instance(), count = adsBlocked,
                        last = s.tunnelRecentAds().lastOrNull() ?:
                        ctx.getString(R.string.notification_keepalive_none)
                )
            }
            var w: IWhen? = null
            s.keepAlive.doWhenSet().then {
                if (s.keepAlive()) {
                    s.tunnelAdsCount.cancel(w)
                    w = s.tunnelAdsCount.doOnUiWhenSet().then {
                        keepAliveNotificationUpdater(s.tunnelAdsCount())
                    }
                    keepAliveAgent.bind(ctx)
                } else {
                    hideNotificationKeepAlive(ctx)
                    s.tunnelAdsCount.cancel(w)
                    keepAliveAgent.unbind(ctx)
                }
            }

            // Display notifications for blocked ads
            s.tunnelRecentAds.doOnUiWhenSet().then {
                if (s.tunnelRecentAds().isEmpty()) hideNotification(ctx)
                else if (ui.notifications()) displayNotification(ctx, s.tunnelRecentAds().last())
            }

            // Hide notification when disabled
            ui.notifications.doOnUiWhenSet().then {
                hideNotification(ctx)
            }

            // Display an info message when update is available
            s.repo.doOnUiWhenSet().then {
                if (isUpdate(ctx, s.repo().newestVersionCode)) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, R.string.update_infotext)
                    ui.lastSeenUpdateMillis.refresh(force = true)
                }
            }

            // Display notifications for updates
            ui.lastSeenUpdateMillis.doOnUiWhenSet().then {
                val u = s.repo()
                val last = ui.lastSeenUpdateMillis()
                val cooldown = s.repoConfig().notificationCooldownMillis
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
                registerUncaughtExceptionHandler(ctx)
            }

            // Initialize default values for properties that need it (async)
            s.tunnelAdsCount {}
            s.startOnBoot {}
            s.keepAlive {}
            s.tunnelActiveEngine {}
            s.filtersCompiled {}

            // This will fetch locale configuration unless already cached
            s.repo {}
        }
    }
}

// So that it's never GC'd, not sure if it actually does anything
private val keepAliveAgent by lazy { AKeepAliveAgent() }
