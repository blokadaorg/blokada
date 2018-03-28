package core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import com.github.salomonbrys.kodein.*
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.presentation.SimpleDialog
import gs.presentation.WebDash
import gs.property.*
import org.blokada.R

abstract class Welcome {
    abstract val introSeen: IProperty<Boolean>
    abstract val guideSeen: IProperty<Boolean>
    abstract val patronShow: IProperty<Boolean>
    abstract val patronSeen: IProperty<Boolean>
    abstract val ctaSeenCounter: IProperty<Int>
    abstract val advanced: IProperty<Boolean>
    abstract val conflictingBuilds: IProperty<List<String>>
}

class WelcomeImpl (
        w: Worker,
        xx: Environment,
        val i18n: I18n = xx().instance(),
        val j: Journal = xx().instance()
) : Welcome() {
    override val introSeen = newPersistedProperty(w, BasicPersistence(xx, "intro_seen"), { false })
    override val guideSeen = newPersistedProperty(w, BasicPersistence(xx, "guide_seen"), { false })
    override val patronShow = newProperty(w, { false })
    override val patronSeen = newPersistedProperty(w, BasicPersistence(xx, "optional_seen"), { false })
    override val ctaSeenCounter = newPersistedProperty(w, BasicPersistence(xx, "cta_seen"), { 3 })
    override val advanced = newPersistedProperty(w, BasicPersistence(xx, "advanced"), { false })
    override val conflictingBuilds = newProperty(w, { listOf<String>() })

    init {
        i18n.locale.doWhenSet().then {
            val root = i18n.contentUrl()
            j.log("welcome: locale set: contentUrl: $root")
            patronShow %= true
        }

        conflictingBuilds %= listOf("org.blokada.origin.alarm", "org.blokada.alarm", "org.blokada", "org.blokada.dev")
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

    private var displaying = false

    init {
        pages.loaded.doOnUiWhenChanged(withInit = true).then {
            run()
        }
        version.obsolete.doOnUiWhenChanged(withInit = true).then {
            run()
        }
    }

    fun run(step: Int = 0) {
        when {
            !pages.loaded() -> Unit
            displaying -> Unit
            step == 0 && version.obsolete() -> {
                dialogObsolete.onClosed = { accept ->
                    displaying = false
                    if (accept == 1) {
                        OpenInBrowserDash(ctx, pages.download).onClick?.invoke(0)
                    }
                }
                dialogObsolete.show()
                displaying = true
            }
            step == 0 && !welcome.introSeen() -> {
                dialogIntro.onClosed = { accept ->
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
                dialogIntro.show()
                displaying = true
            }
            step == 0 && version.previousCode() < currentAppVersion -> {
                version.previousCode %= currentAppVersion
                dialogUpdate.onClosed = { accept ->
                    displaying = false
                    if (accept == 1) {
                        OpenInBrowserDash(ctx, pages.donate).onClick?.invoke(0)
                    } else if (accept == 2) {
                        run(step = 2)
                    }
                }
                dialogUpdate.show()
                displaying = true
            }
            step == 0 && welcome.ctaSeenCounter() > 0 -> {
                welcome.ctaSeenCounter %= welcome.ctaSeenCounter() - 1
                run(step = 9)
            }
            step == 0 && welcome.ctaSeenCounter() == 0 -> {
                dialogCta.onClosed = { accept ->
                    displaying = false
                    if (accept == 1) welcome.ctaSeenCounter %= 5
                    run(step = 9)
                }
                dialogCta.show()
                displaying = true
            }
            step == 1 -> {
                dialogGuide.onClosed = { accept ->
                    displaying = false
                    if (accept == 1) {
                    } else if (accept == 2) {
                        OpenInBrowserDash(ctx, pages.help).onClick?.invoke(0)
                    }
                    run(step = 9)
                }
                dialogGuide.show()
                displaying = true
            }
            step == 2 && welcome.patronShow() -> {
                dialogPatron.onClosed = { button ->
                    displaying = false
                    if (button == 1) {
                        OpenInBrowserDash(ctx, pages.patron).onClick?.invoke(0)
                    }
                    welcome.patronSeen %= true
                    run(step = 9)
                }
                dialogPatron.show()
                displaying = true
            }
            getInstalledBuilds().size > 1 -> {
                dialogCleanup.onClosed = { accept ->
                    displaying = false
                    if (accept == 1) {
                        Toast.makeText(ctx, R.string.welcome_cleanup_done, Toast.LENGTH_SHORT).show()
                        val builds = getInstalledBuilds()
                        for (b in builds.subList(1, builds.size).reversed()) {
                            uninstallPackage(b)
                        }
                    }
                }
                dialogCleanup.show()
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
        val dash = WebDash(xx, pages.intro, reloadOnError = true)
        SimpleDialog(xx, dash, additionalButton = R.string.welcome_help, loadFirst = true)
    }

    private val dialogGuide by lazy {
        val dash = WebDash(xx, pages.help, reloadOnError = true)
        SimpleDialog(xx, dash, additionalButton = R.string.welcome_open, loadFirst = true)
    }

    private val dialogPatron by lazy {
        val dash = WebDash(xx, pages.patron, reloadOnError = true, forceEmbedded = true,
                javascript = true, big = true)
        SimpleDialog(xx, dash, continueButton = R.string.welcome_open, loadFirst = true)
    }

    private val dialogCta by lazy {
        val dash = WebDash(xx, pages.cta, reloadOnError = true)
        SimpleDialog(xx, dash, loadFirst = true)
    }

    private val dialogUpdate by lazy {
        val dash = WebDash(xx, pages.updated, reloadOnError = true)
       SimpleDialog(xx, dash, continueButton = R.string.welcome_donate, additionalButton = R.string.welcome_insiders,
               loadFirst = true)
    }

    private val dialogObsolete by lazy {
        val dash = WebDash(xx, pages.obsolete, reloadOnError = true)
        SimpleDialog(xx, dash, continueButton = R.string.update_button, loadFirst = true)
    }

    private val dialogCleanup by lazy {
        val dash = WebDash(xx, pages.cleanup, reloadOnError = true)
        SimpleDialog(xx, dash, loadFirst = true)
    }

}
