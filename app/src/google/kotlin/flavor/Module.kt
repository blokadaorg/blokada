package flavor

import android.app.NotificationManager
import android.content.Context
import com.github.salomonbrys.kodein.*
import core.*
import filter.DashFilterWhitelist
import gs.property.IWhen
import notification.NotificationDashKeepAlive
import notification.createNotificationKeepAlive
import update.AboutDash
import update.UpdateDash

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        onReady {
            val s: Tunnel = instance()
            val k: KeepAlive = instance()
            val d: Dns = instance()

            // Keep DNS servers up to date on notification
            val keepAliveNotificationUpdater = {
                val nm: NotificationManager = instance()
                val n = createNotificationKeepAlive(ctx = ctx, count = 0, last = "")
                nm.notify(3, n)
            }
            var w: IWhen? = null
            k.keepAlive.doWhenSet().then {
                if (k.keepAlive()) {
                    w = d.dnsServers.doOnUiWhenSet().then {
                        keepAliveNotificationUpdater()
                    }
                } else {
                    d.dnsServers.cancel(w)
                    // Will be turned off by logic in core module
                }
            }

            // Initialize default values for properties that need it (async)
            s.tunnelDropCount {}
        }
    }
}

