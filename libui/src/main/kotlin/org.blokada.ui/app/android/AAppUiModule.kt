package org.blokada.ui.app.android

import android.content.Context
import com.github.salomonbrys.kodein.*
import org.blokada.app.Events
import org.blokada.app.IFilterSource
import org.blokada.app.State
import org.blokada.app.android.AKeepAliveAgent
import org.blokada.framework.IEnvironment
import org.blokada.framework.IJournal
import org.blokada.framework.IWhen
import org.blokada.framework.android.AActivityContext
import org.blokada.lib.ui.R
import org.blokada.ui.app.Info
import org.blokada.ui.app.InfoType
import org.blokada.ui.app.UiState

// So that it's never GC'd, not sure if it actually does anything
private val keepAliveAgent by lazy { AKeepAliveAgent() }

fun newAndroidAppUiModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<UiState>() with singleton { AUiState(ctx, kctx = with("uistate").instance(10)) }
        bind<AActivityContext<MainActivity>>() with singleton { AActivityContext<MainActivity>() }
        bind<AFilterAddDialog>() with provider { AFilterAddDialog(ctx,
                sourceProvider = { type: String -> with(type).instance<IFilterSource>() }
        ) }

        onReady {
            val s: State = instance()
            val ui: UiState = instance()

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
                val env: IEnvironment = instance()
                val j: IJournal = instance()

                if (isUpdate(ctx, u.newestVersionCode) && canShowNotification(last, env, cooldown)) {
                    displayNotificationForUpdate(ctx, u.newestVersionName)
                    ui.lastSeenUpdateMillis %= env.now()
                    j.event(Events.UPDATE_NOTIFY)
                }
            }
        }
    }
}
