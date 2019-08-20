package core

import android.content.Context
import com.github.salomonbrys.kodein.*
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Time
import gs.environment.Worker
import gs.property.IProperty
import gs.property.Repo
import gs.property.newPersistedProperty
import notification.displayNotificationForUpdate
import org.blokada.BuildConfig
import update.AUpdateDownloader
import update.UpdateCoordinator

abstract class Update {
    abstract val lastSeenUpdateMillis: IProperty<Long>
}

class UpdateImpl (
        w: Worker,
        xx: Environment,
        val ctx: Context = xx().instance()
) : Update() {

    override val lastSeenUpdateMillis = newPersistedProperty(w, APrefsPersistence(ctx, "lastSeenUpdate"),
            { 0L })
}

fun newUpdateModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Update>() with singleton {
            UpdateImpl(w = with("gscore").instance(), xx = lazy)
        }
        bind<UpdateCoordinator>() with singleton {
            UpdateCoordinator(xx = lazy, downloader = AUpdateDownloader(ctx = instance()))
        }
        onReady {
            val s: Filters = instance()
            val t: Tunnel = instance()
            val ui: UiState = instance()
            val u: Update = instance()
            val repo: Repo = instance()

            // Check for update periodically
            t.tunnelState.doWhen { t.tunnelState(TunnelState.ACTIVE) }.then {
                // This "pokes" the cache and refreshes if needed
                repo.content.refresh()
            }

            // Display an info message when update is available
            repo.content.doOnUiWhenSet().then {
                if (isUpdate(ctx, repo.content().newestVersionCode)) {
                    u.lastSeenUpdateMillis.refresh(force = true)
                }
            }

            // Display notifications for updates
            u.lastSeenUpdateMillis.doOnUiWhenSet().then {
                val content = repo.content()
                val last = u.lastSeenUpdateMillis()
                val cooldown = 86400 * 1000L
                val env: Time = instance()
                val j: Journal = instance()

                if (isUpdate(ctx, content.newestVersionCode) && canShowNotification(last, env, cooldown)) {
                    displayNotificationForUpdate(ctx, content.newestVersionName)
                    u.lastSeenUpdateMillis %= env.now()
                }
            }


        }
    }
}

internal fun canShowNotification(last: Long, env: Time, cooldownMillis: Long): Boolean {
    return last + cooldownMillis < env.now()
}

fun isUpdate(ctx: Context, code: Int): Boolean {
    return code > BuildConfig.VERSION_CODE
}
