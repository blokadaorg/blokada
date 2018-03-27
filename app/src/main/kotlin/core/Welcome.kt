package core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.support.v4.app.ShareCompat
import android.widget.Toast
import com.github.salomonbrys.kodein.*
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.presentation.SimpleDialog
import gs.presentation.WebViewActor
import gs.presentation.toPx
import gs.property.*
import org.blokada.R
import java.net.URL

abstract class Welcome {
    abstract val introUrl: IProperty<URL>
    abstract val introSeen: IProperty<Boolean>
    abstract val guideSeen: IProperty<Boolean>
    abstract val patronShow: IProperty<Boolean>
    abstract val patronSeen: IProperty<Boolean>
    abstract val ctaUrl: IProperty<URL>
    abstract val ctaSeenCounter: IProperty<Int>
    abstract val updatedUrl: IProperty<URL>
    abstract val advanced: IProperty<Boolean>
    abstract val obsoleteUrl: IProperty<URL>
    abstract val cleanupUrl: IProperty<URL>
    abstract val conflictingBuilds: IProperty<List<String>>
}

class WelcomeImpl (
        w: Worker,
        xx: Environment,
        val i18n: I18n = xx().instance(),
        val j: Journal = xx().instance()
) : Welcome() {
    override val introUrl = newProperty(w, { URL("http://localhost") })
    override val introSeen = newPersistedProperty(w, BasicPersistence(xx, "intro_seen"), { false })
    override val guideSeen = newPersistedProperty(w, BasicPersistence(xx, "guide_seen"), { false })
    override val patronShow = newProperty(w, { false })
    override val patronSeen = newPersistedProperty(w, BasicPersistence(xx, "optional_seen"), { false })
    override val ctaUrl = newProperty(w, { URL("http://localhost") })
    override val ctaSeenCounter = newPersistedProperty(w, BasicPersistence(xx, "cta_seen"), { 3 })
    override val updatedUrl = newProperty(w, { URL("http://localhost") })
    override val advanced = newPersistedProperty(w, BasicPersistence(xx, "advanced"), { false })
    override val obsoleteUrl = newProperty(w, { URL("http://localhost") })
    override val cleanupUrl = newProperty(w, { URL("http://localhost") })
    override val conflictingBuilds = newProperty(w, { listOf<String>() })

    init {
        i18n.locale.doWhenSet().then {
            val root = i18n.contentUrl()
            j.log("setting locale. contentUrl: $root")
            updatedUrl %= URL("${root}/updated.html")
            cleanupUrl %= URL("${root}/cleanup.html")
            ctaUrl %= URL("${root}/cta.html")
            patronShow %= true
            // Last one because it triggers dialogs
            introUrl %= URL("${root}/intro.html")
        }

        conflictingBuilds %= listOf("org.blokada.origin.alarm", "org.blokada.alarm", "org.blokada", "org.blokada.dev")
        obsoleteUrl %= URL("https://blokada.org/api/legacy/content/root/obsolete.html")
    }
}

fun newWelcomeModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Welcome>() with singleton {
            WelcomeImpl(w = with("gscore").instance(2), xx = lazy)
        }
    }
}

class WelcomeDialogManager (
        private val xx: Environment,
        private val currentAppVersion: Int,
        private val afterWelcome: () -> Unit
) {

    private val ctx: Context by xx.instance()
    private val welcome: Welcome by xx.instance()
    private val version: Version by xx.instance()
    private val pages: Pages by xx.instance()
    private val j: Journal by xx.instance()
    private val activity: ComponentProvider<Activity> by xx.instance()

    private var displaying = false

    fun run(step: Int = 0) {
        when {
            displaying -> Unit
            step == 0 && version.obsolete() -> dialogObsolete.show()
            step == 0 && !welcome.introSeen() -> {
                dialogIntro.listener = { accept ->
                    displaying = false
                    if (accept == 1) {
                        welcome.introSeen %= true
                        afterWelcome()
                        run(step = 9)
                    } else if (accept == 2) {
                        welcome.introSeen %= true
                        run(step = 1)
                    } else {
                        run(step = 9)
                    }
                }
                // Shows immediately and loads website
                dialogIntro.show()
                displaying = true
            }
            step == 0 && version.previousCode() < currentAppVersion -> {
                version.previousCode %= currentAppVersion
                dialogUpdate.listener = { accept ->
                    displaying = false
                    if (accept == 1) {
                        OpenInBrowserDash(ctx, pages.donate).onClick?.invoke(0)
                    } else if (accept == 2) {
                        run(step = 2)
                    } else {
                        run(step = 2)
                    }
                }
                // Will display once website is loaded
                displaying = true
            }
            step == 0 && welcome.ctaSeenCounter() > 0 -> {
                welcome.ctaSeenCounter %= welcome.ctaSeenCounter() - 1
                run(step = 9)
            }
            step == 0 && welcome.ctaSeenCounter() == 0 -> {
                dialogCta.listener = { accept ->
                    displaying = false
                    if (accept == 1) welcome.ctaSeenCounter %= 5
                    run(step = 9)
                }
                // Will display once website is loaded
                displaying = true
            }
            step == 1 -> {
                dialogGuide.listener = { accept ->
                    displaying = false
                    if (accept == 1) {
                    } else if (accept == 2) {
                        guideActor?.openInBrowser()
                    }
                    run(step = 9)
                }
                // Shows immediately and loads website
                dialogGuide.show()
                displaying = true
            }
            step == 2 && welcome.patronShow() -> {
                dialogPatron.listener = { button ->
                    displaying = false
                    if (button == 1) {
                        patronActor?.openInBrowser()
                    } else if (button == 2) {
                        ShareCompat.IntentBuilder.from(activity.get())
                                .setType("text/plain")
                                .setChooserTitle(R.string.welcome_share)
                                .setText(pages.patron().toExternalForm())
                                .startChooser();
                    }
                    welcome.patronSeen %= true
                    run(step = 9)
                }
                // Will display once website is loaded
                displaying = true
            }
            getInstalledBuilds().size > 1 -> {
                dialogCleanup.listener = { accept ->
                    displaying = false
                    if (accept == 1) {
                        Toast.makeText(ctx, R.string.welcome_cleanup_done, Toast.LENGTH_SHORT).show()
                        val builds = getInstalledBuilds()
                        for (b in builds.subList(1, builds.size).reversed()) {
                            uninstallPackage(b)
                        }
                    }
                }
                // Will display once website is loaded
                displaying = true
            }
        }
    }

    private fun getInstalledBuilds(): List<String> {
        return welcome.conflictingBuilds().map {
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

    private val dialogIntro by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview, additionalButton = R.string.welcome_help)
        WebViewActor(dialog, welcome.introUrl, reloadOnError = true)
        dialog
    }

    private val dialogGuide by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview, additionalButton = R.string.welcome_open)
        guideActor = WebViewActor(dialog, pages.help, reloadOnError = true, showDialog = true)
        dialog
    }

    private var guideActor: WebViewActor? = null

    private val dialogPatron by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview_patron, continueButton = R.string.welcome_open,
                additionalButton = R.string.welcome_share)
        dialog.view.minimumHeight = ctx.resources.toPx(480)
        patronActor = WebViewActor(dialog, pages.patron, forceEmbedded = true,
                javascript = true, showDialog = true)
        dialog
    }

    private var patronActor: WebViewActor? = null

    private val dialogCta by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview)
        WebViewActor(dialog, welcome.ctaUrl, reloadOnError = true, showDialog = true)
        dialog
    }

    private val dialogUpdate by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview, continueButton = R.string.welcome_donate,
                additionalButton = R.string.welcome_patron)
        WebViewActor(dialog, welcome.updatedUrl, reloadOnError = true, showDialog = true)
        dialog
    }

    private val dialogObsolete by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview)
        WebViewActor(dialog, welcome.obsoleteUrl, reloadOnError = true, showDialog = true)
        dialog
    }

    private val dialogCleanup by lazy {
        val dialog = SimpleDialog(ctx, R.layout.webview)
        WebViewActor(dialog, welcome.cleanupUrl, reloadOnError = true, showDialog = true)
        dialog
    }

}
