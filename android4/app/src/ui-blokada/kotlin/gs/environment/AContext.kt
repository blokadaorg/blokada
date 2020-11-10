package gs.environment

import android.app.AlarmManager
import android.app.DownloadManager
import android.app.NotificationManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.PowerManager
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.singleton
import nl.komponents.kovenant.android.androidUiDispatcher
import nl.komponents.kovenant.ui.KovenantUi
import java.lang.ref.WeakReference

/**
 * Contains various structures related to Android Context.
 */

val Context.inject: () -> Kodein get() = { (applicationContext as KodeinAware).kodein }

/**
 * ComponentProvider wraps activity context in a weak reference in order to deliver it to interested
 * parties while not leaking it.
 */
class ComponentProvider<T: Context> : LazyProvider<T>()

open class LazyProvider<T> {
    private var value: WeakReference<T>? = null

    @Synchronized fun get(): T? {
        return value?.get()
    }

    @Synchronized fun set(v: T) {
        value = WeakReference(v)
    }

    @Synchronized fun unset() {
        value = null
    }
}

fun newAndroidModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        // Android components for easier access
        bind<Context>() with singleton { ctx }
        bind<ConnectivityManager>() with singleton {
            ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        }
        bind<WifiManager>() with singleton {
            ctx.getSystemService(Context.WIFI_SERVICE) as WifiManager
        }
        bind<DownloadManager>() with singleton {
            ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        }
        bind<AlarmManager>() with singleton {
            ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        }
        bind<NotificationManager>() with singleton {
            ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }
        bind<PowerManager>() with singleton {
            ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        }

        onReady {
            KovenantUi.uiContext {
                dispatcher = androidUiDispatcher()
            }
        }
    }
}


