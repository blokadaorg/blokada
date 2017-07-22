package org.blokada.ui.app.android

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import org.blokada.app.android.AUpdateDownloader
import org.blokada.app.VersionConfig
import org.blokada.lib.ui.R
import org.blokada.app.State
import org.blokada.app.TunnelState
import org.blokada.app.UpdateCoordinator
import org.blokada.framework.IWhen
import org.blokada.framework.android.di
import org.blokada.ui.app.Dash
import org.blokada.ui.app.UiState

val DASH_ID_ABOUT = "update_about"

class AboutDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(DASH_ID_ABOUT,
        R.drawable.ic_info,
        ctx.getString(R.string.update_about_desc),
        text = ctx.getString(R.string.update_about),
        hasView = true,
        topBarColor = R.color.colorBackgroundAboutLight
) {

    override fun createView(parent: Any): Any? {
        return createUpdateView(ctx, parent as ViewGroup, s)
    }
}

class UpdateDash(
        val ctx: Context,
        val s: State = ctx.di().instance(),
        val ui: UiState = ctx.di().instance()
) : Dash("update_update",
        R.drawable.ic_info,
        ctx.getString(R.string.update_dash_desc),
        text = ctx.getString(R.string.update_dash_uptodate),
        menuDashes = Triple(UpdateForceDash(ctx, s), null, null),
        hasView = true,
        topBarColor = R.color.colorBackgroundAboutLight,
        onDashOpen = {
            updateView?.canClick = true
        }
) {

    private val listener: Any
    init {
        listener = s.repo.doOnUiWhenSet().then {
            update(s.repo().newestVersionCode)
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
        val context = if (parent is View) parent.context else ctx
        return createUpdateView(context, parent as ViewGroup, s)
    }
}

private var listener: IWhen? = null
private var updateView: AUpdateView? = null
private fun createUpdateView(ctx: Context, parent: ViewGroup, s: State): AUpdateView {
    val view = LayoutInflater.from(ctx).inflate(R.layout.view_update, parent, false) as AUpdateView
    if (view is AUpdateView) {
        val u = s.repo()
        val updater: UpdateCoordinator = ctx.di().instance()

        view.update = if (isUpdate(ctx, u.newestVersionCode))
            (u.newestVersionName to s.localised().changelog)
        else null

        view.onClick = {
            Toast.makeText(ctx, R.string.update_starting, Toast.LENGTH_SHORT).show()
            updater.start(u.downloadLinks)
        }

        if (listener != null) s.repo.cancel(listener)
        listener = s.repo.doOnUiWhenSet().then {
            val u = s.repo()
            view.update = if (isUpdate(ctx, u.newestVersionCode)) (u.newestVersionName to s.localised().changelog)
            else null
        }
    }
    updateView = view
    return view
}

class UpdateForceDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash("update_force",
        R.drawable.ic_reload,
        ctx.getString(R.string.update_force_dash_desc),
        onClick = { s.repo.refresh(force = true); true }
)

fun isUpdate(ctx: Context, code: Int): Boolean {
    val appVersionCode = ctx.di().instance<VersionConfig>().appVersionCode
    return code > appVersionCode
}
