package update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import core.Dash
import core.UiState
import gs.environment.inject
import gs.property.Repo
import org.blokada.BuildConfig
import org.blokada.R
import tunnel.showSnack

val DASH_ID_ABOUT = "update_about"

class AboutDash(
        val ctx: Context,
        val s: Repo = ctx.inject().instance()
) : Dash(DASH_ID_ABOUT,
        R.drawable.ic_info,
        text = ctx.getString(R.string.update_about),
        hasView = true,
        topBarColor = R.color.colorBackgroundAboutLight
) {

    override fun createView(parent: Any): Any? {
        return createUpdateView(parent as ViewGroup, s)
    }
}

class UpdateDash(
        val ctx: Context,
        val repo: Repo = ctx.inject().instance(),
        val ui: UiState = ctx.inject().instance()
) : Dash("update_update",
        R.drawable.ic_info,
        text = ctx.getString(R.string.update_dash_uptodate),
        menuDashes = Triple(UpdateForceDash(ctx, repo), null, null),
        hasView = true,
        topBarColor = R.color.colorBackgroundAboutLight,
        onDashOpen = {
            updateView?.canClick = true
        }
) {

    private val listener: Any
    init {
        listener = repo.content.doOnUiWhenSet().then {
            update(repo.content().newestVersionCode)
        }
    }

    private fun update(code: Int) {
        when(isUpdate(ctx, code)) {
            true -> {
                active = true
                text = ctx.getString(R.string.update_dash_available)
                icon = R.drawable.ic_new_releases
                ui.dashes %= ui.dashes()
            }
            else -> {
                text = ctx.getString(R.string.update_dash_uptodate)
                icon = R.drawable.ic_info
            }
        }
    }
    override fun createView(parent: Any): Any? {
        return createUpdateView(parent as ViewGroup, repo)
    }
}

private var listener: gs.property.IWhen? = null
private var updateView: AUpdateView? = null
private var next: Int = 0
private fun createUpdateView(parent: ViewGroup, s: Repo): AUpdateView {
    val ctx = parent.context
    val view = LayoutInflater.from(ctx).inflate(R.layout.view_update, parent, false) as AUpdateView
    if (view is AUpdateView) {
        val u = s.content()
        val updater: UpdateCoordinator = ctx.inject().instance()

        view.update = if (isUpdate(ctx, u.newestVersionCode))
            u.newestVersionName
        else null

        view.onClick = {
            showSnack(R.string.update_starting)
            updater.start(u.downloadLinks)
        }

        view.onClickBackup = {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.setData(Uri.parse(u.downloadLinks[next].toString()))
            ctx.startActivity(intent)

            next = next++ % u.downloadLinks.size
        }

        if (listener != null) s.content.cancel(listener)
        listener = s.content.doOnUiWhenSet().then {
            val u = s.content()
            view.update = if (isUpdate(ctx, u.newestVersionCode)) u.newestVersionName
            else null
        }
    }
    updateView = view
    return view
}

class UpdateForceDash(
        val ctx: Context,
        val s: Repo = ctx.inject().instance()
) : Dash("update_force",
        R.drawable.ic_reload,
        onClick = { s.content.refresh(force = true); true }
)

fun isUpdate(ctx: Context, code: Int): Boolean {
    return code > BuildConfig.VERSION_CODE
}
