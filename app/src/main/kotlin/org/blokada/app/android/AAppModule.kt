package org.blokada.app.android

import android.app.AlarmManager
import android.app.DownloadManager
import android.app.NotificationManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.PowerManager
import com.github.salomonbrys.kodein.*
import nl.komponents.kovenant.android.androidUiDispatcher
import nl.komponents.kovenant.task
import nl.komponents.kovenant.ui.KovenantUi
import org.blokada.app.*
import org.blokada.framework.IEnvironment
import org.blokada.framework.IJournal
import org.blokada.framework.android.AEnvironment


fun newAndroidAppModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        // The main state
        bind<State>() with singleton {
            AState(ctx, kctx = with("state").instance(10))
        }

        // EngineManager that can switch between concrete engines
        bind<IEngineManager>() with singleton {
            val s: State = instance()
            val j: IJournal = instance()

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
        bind<IEnvironment>() with singleton { AEnvironment() }
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
        bind<FilterSerializer>() with singleton { FilterSerializer(s = instance(),
                sourceProvider = { type: String -> with(type).instance<IFilterSource>() })
        }

        onReady {
            KovenantUi.uiContext {
                dispatcher = androidUiDispatcher()
            }

            // Register various Android listeners to receive events
            task {
                // In a task because we are in DI and using DI can lead to stack overflow
                AConnectivityReceiver.register(ctx)
                AScreenOnReceiver.register(ctx)
                ALocaleReceiver.register(ctx)
                registerUncaughtExceptionHandler(ctx)
            }

            val s: State = instance()

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

