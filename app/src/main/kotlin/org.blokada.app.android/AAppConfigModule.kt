package org.blokada.app.android

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import com.github.salomonbrys.kodein.*
import gs.environment.AActivityProvider
import gs.property.Welcome
import gs.property.WelcomeImpl
import org.blokada.BuildConfig
import org.blokada.R
import org.blokada.app.*
import org.blokada.app.android.lollipop.ALollipopEngineManager
import org.blokada.framework.android.getPersistencePath
import org.blokada.framework.android.getPublicPersistencePath
import org.blokada.ui.app.android.MainActivity
import java.io.File
import java.net.URL

fun newAndroidAppConfigModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<FilterConfig>(overrides = true) with singleton { FilterConfig(
                cacheFile = File(getPersistencePath(ctx).absoluteFile, "filters"),
                exportFile = getPublicPersistencePath("blokada-export") ?:
                    File(getPersistencePath(ctx).absoluteFile, "blokada-export"),
                cacheTTLMillis = 7 * 24 * 60 * 60 * 100L, // A week
                repoURL = URL("http://blokada.org/api/${BuildConfig.VERSION_CODE}/${BuildConfig.FLAVOR}/filters.txt"),
                fetchTimeoutMillis = 10 * 1000
        ) }
        bind<RepoConfig>(overrides = true) with singleton { RepoConfig(
                cacheFile = File(getPersistencePath(ctx).absoluteFile, "repo"),
                cacheTTLMillis = 24 * 60 * 60 * 1000L, // A day
                repoURL = URL("http://blokada.org/api/${BuildConfig.VERSION_CODE}/${BuildConfig.FLAVOR}/repo.txt"),
                fetchTimeoutMillis = 10 * 1000,
                notificationCooldownMillis = 24 * 60 * 60 * 1000L // A day
        ) }
        bind<VersionConfig>(overrides = true) with singleton { VersionConfig(
                appName = ctx.getString(R.string.branding_app_name),
                appVersion = BuildConfig.VERSION_NAME,
                appVersionCode = BuildConfig.VERSION_CODE,
                coreVersion = org.blokada.BuildConfig.VERSION_NAME,
                uiVersion = org.blokada.BuildConfig.VERSION_NAME
        ) }
        bind<TunnelConfig>(overrides = true) with singleton { TunnelConfig(defaultEngine = "lollipop") }
        bind<List<Engine>>(overrides = true) with singleton { listOf(Engine(
                id = "lollipop",
                text = ctx.getString(R.string.tunnel_selected_lollipop),
                comment = ctx.getString(R.string.tunnel_selected_lollipop_desc),
                commentUnsupported = ctx.getString(R.string.tunnel_selected_lollipop_desc_unsupported),
                createIEngineManager = { ALollipopEngineManager(ctx,
                        agent = instance(),
                        adBlocked = it.adBlocked,
                        error = it.error,
                        onRevoked = it.onRevoked
                ) }
        )) }
        bind<IPermissionsAsker>(overrides = true) with singleton {
            object : IPermissionsAsker {
                override fun askForPermissions() {
                    MainActivity.askPermissions()
                }
            }
        }
        bind<ATunnelService.IBuilderConfigurator>(overrides = true) with singleton {
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
            val w = WelcomeImpl(w = with("welcome").instance(), xx = instance())
            w.introUrl %= URL("http://blokada.org/content/en/contribute.html")
            w.guideUrl %= URL("http://blokada.org/content/en/help.html")
            w
        }

        bind<AActivityProvider<Activity>>() with singleton { AActivityProvider<Activity>() }
    }
}
