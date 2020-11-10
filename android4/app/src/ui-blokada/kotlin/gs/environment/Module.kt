package gs.environment

import android.app.DownloadManager
import android.app.NotificationManager
import android.content.Context
import android.os.PowerManager
import android.view.View
import com.github.salomonbrys.kodein.*
import gs.property.*
import nl.komponents.kovenant.android.androidUiDispatcher
import nl.komponents.kovenant.ui.KovenantUi

fun newGscoreModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Context>() with singleton { ctx }
        bind<Journal>() with singleton { ALogcatJournal("gscore") }
        bind<Time>() with singleton { SystemTime() }

        bind<Worker>() with multiton { it: String ->
            newSingleThreadedWorker(j = instance(), prefix = it)
        }
        bind<Worker>(2) with multiton { it: String ->
            newConcurrentWorker(j = instance(), prefix = it, tasks = 1)
        }
        bind<Worker>(3) with multiton { it: String ->
            newConcurrentWorker(j = instance(), prefix = it, tasks = 1)
        }
        bind<Worker>(10) with multiton { it: String ->
            newConcurrentWorker(j = instance(), prefix = it, tasks = 1)
        }

        bind<Serialiser>() with multiton { it: String ->
            SharedPreferencesWrapper(ctx.getSharedPreferences(it, 0))
        }

        bind<Version>() with singleton {
            VersionImpl(kctx = with("gscore").instance(2), xx = lazy)
        }
        bind<Repo>() with singleton {
            RepoImpl(kctx = with("gscore").instance(2), xx = lazy)
        }
        bind<I18n>() with singleton {
            I18nImpl(xx = lazy, kctx = with("gscore").instance(2))
        }
        bind<I18nPersistence>() with multiton { it: LanguageTag ->
            I18nPersistence(xx = lazy, locale = it)
        }

        bind<LazyProvider<View>>() with multiton { it: String -> LazyProvider<View>() }

        bind<DownloadManager>() with singleton {
            ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        }
        bind<NotificationManager>() with singleton {
            ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }
        bind<PowerManager>() with singleton {
            ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        }

        KovenantUi.uiContext {
            dispatcher = androidUiDispatcher()
        }
    }
}
