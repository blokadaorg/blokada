package org.blokada.app.android

import android.net.VpnService
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.singleton
import org.blokada.app.*
import org.blokada.framework.IJournal
import java.io.File
import java.net.URL


fun newAndroidAppDummyConfigModule(): Kodein.Module {
    return Kodein.Module {
        // Dummy / debug components that should be overridden upstream
        bind<FilterConfig>() with singleton {
            FilterConfig(
                    cacheFile = File("dummy-filters"),
                    exportFile = File("dummy-export"),
                    cacheTTLMillis = 7 * 24 * 60 * 60 * 100L, // A week
                    repoURL = URL("http://blokada.org/api/20/dev/filters.txt"),
                    fetchTimeoutMillis = 10 * 1000
            )
        }
        bind<RepoConfig>() with singleton {
            RepoConfig(
                    cacheFile = File("dummy-repo"),
                    cacheTTLMillis = 24 * 60 * 60 * 1000L, // A day
                    repoURL = URL("http://blokada.org/api/20/dev/repo.txt"),
                    fetchTimeoutMillis = 10 * 1000,
                    notificationCooldownMillis = 24 * 60 * 60 * 1000L // A day
            )
        }
        bind<VersionConfig>() with singleton {
            VersionConfig(
                    appName = "Blokada (dummy)",
                    appVersion = "0.o",
                    appVersionCode = 0,
                    coreVersion = "o.0",
                    uiVersion = "(o.o)"
            )
        }
        bind<TunnelConfig>() with singleton { TunnelConfig(defaultEngine = "dummy") }
        bind<List<Engine>>() with singleton {
            listOf(Engine(
                    id = "dummy",
                    text = "Dummy engine",
                    comment = "This should be replaced by upstream.",
                    createIEngineManager = { e: EngineEvents ->
                        object : IEngineManager {
                            override fun start() {}
                            override fun updateFilters() {}
                            override fun stop() {}
                        }
                    }
            ))
        }
        bind<IPermissionsAsker>() with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {}
            }
        }
        bind<IJournal>() with singleton { ALogcatJournal("blokada") }
        bind<ATunnelService.IBuilderConfigurator>() with singleton {
            object : ATunnelService.IBuilderConfigurator {
                override fun configure(builder: VpnService.Builder) {
                    builder.setSession("VPN (dummy)")
                }
            }
        }

    }
}

