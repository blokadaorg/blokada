package flavor

import adblocker.ALollipopEngineManager
import adblocker.TunnelDashCountDropped
import adblocker.TunnelDashHostsCount
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import com.github.salomonbrys.kodein.*
import core.*
import filter.DashFilterBlacklist
import filter.DashFilterWhitelist
import gs.environment.Journal
import notification.NotificationDashKeepAlive
import notification.NotificationDashOn
import notification.displayNotification
import notification.hideNotification
import org.blokada.R
import tunnel.ATunnelService
import update.AboutDash
import update.UpdateDash

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        // EngineManager that can switch between concrete engines
        bind<IEngineManager>() with singleton {
            val s: Tunnel = instance()
            val j: Journal = instance()

            ALollipopEngineManager(ctx,
                    adBlocked = { host ->
                        s.tunnelDropCount %= s.tunnelDropCount() + 1
                        val dropped = s.tunnelRecentDropped() + host
                        s.tunnelRecentDropped %= dropped.takeLast(10)
                    },
                    error = {
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

                    })
        }
        bind<List<Engine>>() with singleton {
            listOf(Engine(
                    id = "lollipop",
                    createIEngineManager = {
                        ALollipopEngineManager(ctx,
                                adBlocked = it.adBlocked,
                                error = it.error,
                                onRevoked = it.onRevoked
                        )
                    }
            ))
        }
        bind<ATunnelService.IBuilderConfigurator>() with singleton {
            val dns: Dns = instance()
            object : ATunnelService.IBuilderConfigurator {
                override fun configure(builder: VpnService.Builder) {
                    builder.setSession(ctx.getString(R.string.branding_app_name))
                            .setConfigureIntent(PendingIntent.getActivity(ctx, 1,
                                    Intent(ctx, MainActivity::class.java),
                                    PendingIntent.FLAG_CANCEL_CURRENT))
                }
            }
        }
        bind<List<Dash>>() with singleton {
            listOf(
                    UpdateDash(ctx).activate(true),
                    TunnelDashCountDropped(ctx).activate(true),
                    DashFilterBlacklist(ctx).activate(true),
                    DashFilterWhitelist(ctx).activate(true),
                    DashDns(lazy).activate(true),
                    NotificationDashOn(ctx).activate(true),
                    NotificationDashKeepAlive(ctx).activate(true),
                    AutoStartDash(ctx).activate(true),
                    ConnectivityDash(ctx).activate(true),
                    TunnelDashHostsCount(ctx).activate(true),
                    PatronDash(lazy).activate(false),
                    PatronAboutDash(lazy).activate(false),
                    DonateDash(lazy).activate(false),
                    NewsDash(lazy).activate(false),
                    FeedbackDash(lazy).activate(false),
                    FaqDash(lazy).activate(false),
                    ChangelogDash(lazy).activate(false),
                    AboutDash(ctx).activate(false),
                    CreditsDash(lazy).activate(false),
                    CtaDash(lazy).activate(false),
                    ShareLogDash(lazy).activate(false)
            )
        }
        onReady {
            val s: Tunnel = instance()
            val ui: UiState = instance()

            // Show confirmation message to the user whenever notifications are enabled or disabled
            ui.notifications.doWhenChanged().then {
                if (ui.notifications()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_DISABLED)
                }
            }

            // Display notifications for dropped
            s.tunnelRecentDropped.doOnUiWhenSet().then {
                if (s.tunnelRecentDropped().isEmpty()) hideNotification(ctx)
                else if (ui.notifications()) displayNotification(ctx, s.tunnelRecentDropped().last())
            }

            // Hide notification when disabled
            ui.notifications.doOnUiWhenSet().then {
                hideNotification(ctx)
            }

            // Initialize default values for properties that need it (async)
            s.tunnelDropCount {}
        }
    }
}

