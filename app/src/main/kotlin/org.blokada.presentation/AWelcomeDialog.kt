package org.blokada.presentation

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import org.blokada.main.Events
import gs.environment.Journal
import gs.environment.ActivityProvider
import org.blokada.framework.di
import org.blokada.R
import org.blokada.ui.app.UiState
import org.blokada.property.State
import org.blokada.main.UpdateCoordinator
import org.blokada.BuildConfig
import org.blokada.presentation.ContentActor.Companion.X_END
import java.net.URL

class AWelcomeDialog(
        private val ctx: Context,
        private val contentActor: ContentActor
) {

    private val activity by lazy { ctx.di().instance<ActivityProvider<Activity>>().get() }
    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.BlokadaColors_Dialog) }
    private val view = LayoutInflater.from(themedContext).inflate(R.layout.view_welcome, null, false)
            as AWelcomeView
    private val dialog: AlertDialog
    private val j by lazy { ctx.di().instance<Journal>() }
    private val s by lazy { ctx.di().instance<State>() }
    private val ui by lazy { ctx.di().instance<UiState>() }
    private val updater by lazy { ctx.di().instance<UpdateCoordinator>() }
    private var shown = false

    init {
        val d = AlertDialog.Builder(activity)
        d.setView(view)
        dialog = when {
            getInstalledBuilds().size > 1 -> setupForBuildsCleanup(d)
            ctx.packageName == "org.blokada" -> setupForMigration(d)
            ctx.packageName == "org.blokada.dev" -> setupForMigration(d) // Just to test the flow
            s.obsolete() -> setupForObsolete(d)
            ui.version() < BuildConfig.VERSION_CODE -> setupforUpdated(d)
            else -> setupForWelcome(d)
        }
    }

    fun shouldShow(): Boolean {
        return !shown && (ui.seenWelcome(false) || ui.version() < BuildConfig.VERSION_CODE || s.obsolete())
    }

    fun show() {
        ui.seenWelcome %= true
        ui.version %= BuildConfig.VERSION_CODE
        dialog.window.clearFlags(
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
        )
        dialog.show()
        shown = true
    }

    private fun setupForBuildsCleanup(d: AlertDialog.Builder): AlertDialog {
        view.mode = AWelcomeView.Mode.CLEANUP
        d.setPositiveButton(R.string.main_continue, { dia, int ->
            // todo: event
            val builds = getInstalledBuilds()
            for (b in builds.subList(1, builds.size).reversed()) {
                uninstallPackage(b)
                Toast.makeText(ctx, R.string.main_cleanup_done, Toast.LENGTH_SHORT).show()
            }
        })
        d.setNegativeButton(R.string.main_skip, { dia, int -> })
        return d.create()
    }

    private fun setupForMigration(d: AlertDialog.Builder): AlertDialog {
        if (Build.VERSION.SDK_INT >= 21) {
            view.mode = AWelcomeView.Mode.MIGRATE_21
            view.checked = !s.tunnelActiveEngine("legacy")
        } else {
            view.mode = AWelcomeView.Mode.MIGRATE
            view.checked = false
        }

        d.setPositiveButton(R.string.main_install, { dia, int ->
            // TODO: event
            // TODO: https links
            // TODO: not hardcoded urls
            val url = URL(if (view.checked) "http://go.blokada.org/apk2_origin_slim"
                else "http://go.blokada.org/apk2_origin")
            updater.start(listOf(url))
        })
        d.setNegativeButton(R.string.main_skip, { dia, int -> })
        return d.create()
    }

    private fun setupForWelcome(d: AlertDialog.Builder): AlertDialog {
        j.event(Events.Companion.FIRST_WELCOME)
        view.mode = AWelcomeView.Mode.WELCOME
        d.setPositiveButton(R.string.main_continue, { dia, int -> })
        val dialog = d.create()
        dialog.setOnDismissListener {
            if (view.checked) {
                // Activate advanced dashes
                ui.dashes().forEach { dash ->
                    advancedDashes.forEach { advanced ->
                        if (dash.id == advanced) dash.active = true
                    }
                }
                ui.dashes %= ui.dashes()

                j.event(Events.Companion.FIRST_WELCOME_ADVANCED)
            }
        }
        return dialog
    }

    private fun setupForObsolete(d: AlertDialog.Builder): AlertDialog {
        view.mode = AWelcomeView.Mode.OBSOLETE
        d.setPositiveButton(R.string.main_install, { dia, int ->
            // TODO: event
            // TODO: https links
            // TODO: not hardcoded urls
            val url = URL("http://go.blokada.org/apk2_origin")
            updater.start(listOf(url))
        })
        d.setNegativeButton(R.string.main_skip, { dia, int -> })
        return d.create()
    }

    private fun setupforUpdated(d: AlertDialog.Builder): AlertDialog {
        view.mode = AWelcomeView.Mode.UPDATED
        view.checked = true
        d.setPositiveButton(R.string.main_continue, { dia, int -> })
        d.setNegativeButton(R.string.main_skip, { dia, int -> })
        val dialog = d.create()
        dialog.setOnDismissListener {
            val dash = if (view.checked) {
                // Open donate screen
                ui.dashes().firstOrNull { it.id == DASH_ID_DONATE }
            } else {
                // Open support screen (translate, contribute, etc)
                ui.dashes().firstOrNull { it.id == DASH_ID_CONTRIBUTE }
            }

            if (dash != null) {
                contentActor.back {
                    j.event(Events.Companion.CLICK_DASH(dash.id))
                    contentActor.reveal(dash, X_END, 0)
                }
            }
        }
        return dialog
    }

    private fun getInstalledBuilds(): List<String> {
        return listOf("org.blokada.origin.alarm", "org.blokada.alarm", "org.blokada", "org.blokada.dev").map {
            if (isPackageInstalled(it)) it else null
        }.filterNotNull()
    }

    private fun isPackageInstalled(appId: String): Boolean {
        val intent = ctx.packageManager.getLaunchIntentForPackage(appId) as Intent? ?: return false
        val activities = ctx.packageManager.queryIntentActivities(intent, 0)
        return activities.size > 0
    }

    private fun uninstallPackage(appId: String) {
        try {
            val intent = Intent(Intent.ACTION_DELETE)
            intent.data = Uri.parse("package:" + appId)
            ctx.startActivity(intent)
        } catch (e: Exception) {
            j.log(e)
        }
    }

    private val advancedDashes = listOf(
            DASH_ID_STATUS,
            DASH_ID_BLACKLIST,
            DASH_ID_WHITELIST,
            DASH_ID_KEEPALIVE,
            DASH_ID_HOSTS_COUNT,
            DASH_ID_ENGINE_SELECTED,
            DASH_ID_FEEDBACK
    )

}

