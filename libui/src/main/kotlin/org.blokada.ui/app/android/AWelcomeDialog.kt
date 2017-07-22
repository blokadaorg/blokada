package org.blokada.ui.app.android

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
import org.blokada.app.Events
import org.blokada.framework.IJournal
import org.blokada.framework.android.AActivityContext
import org.blokada.framework.android.di
import org.blokada.lib.ui.R
import org.blokada.ui.app.UiState
import org.blokada.app.State
import org.blokada.app.UpdateCoordinator
import java.net.URL

class AWelcomeDialog(
        private val ctx: Context
) {

    private val activity by lazy { ctx.di().instance<AActivityContext<MainActivity>>().getActivity() }
    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.BlokadaColors_Dialog) }
    private val view = LayoutInflater.from(themedContext).inflate(R.layout.view_welcome, null, false)
            as AWelcomeView
    private val dialog: AlertDialog
    private val j by lazy { ctx.di().instance<IJournal>() }
    private val s by lazy { ctx.di().instance<State>() }
    private val ui by lazy { ctx.di().instance<UiState>() }
    private val updater by lazy { ctx.di().instance<UpdateCoordinator>() }

    init {
        val d = AlertDialog.Builder(activity)
        d.setView(view)
        dialog = when {
            getInstalledBuilds().size > 1 -> setupForBuildsCleanup(d)
            ctx.packageName == "org.blokada" -> setupForMigration(d)
            ctx.packageName == "org.blokada.dev" -> setupForMigration(d) // Just to test the flow
            else -> setupForWelcome(d)
        }
    }

    fun shouldShow(): Boolean {
        return ui.seenWelcome(false)
    }

    fun show() {
        ui.seenWelcome %= true
        dialog.window.clearFlags(
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
        )
        dialog.show()

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

