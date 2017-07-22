package org.blokada.ui.app.android

import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import org.blokada.app.EnabledStateActor
import org.blokada.app.Events
import org.blokada.framework.IJournal
import org.blokada.app.IEnabledStateActorListener
import org.blokada.app.State
import org.blokada.framework.IWhen
import org.blokada.framework.android.di
import org.blokada.lib.ui.R
import org.blokada.ui.app.Dash
import org.blokada.ui.app.UiState

val DASH_ID_DONATE = "main_donate"
val DASH_ID_BLOG = "main_blog"
val DASH_ID_FAQ = "main_faq"
val DASH_ID_FEEDBACK = "main_feedback"
val DASH_ID_STATUS = "main_status"
val DASH_ID_BUG = "main_bug"

class DonateDash(val ctx: Context) : Dash(
        DASH_ID_DONATE,
        R.drawable.ic_heart_box,
        ctx.getBrandedString(R.string.main_donate_desc),
        text = ctx.getString(R.string.main_donate_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = ADonateActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class BlogDash(val ctx: Context) : Dash(
        DASH_ID_BLOG,
        R.drawable.ic_comment_multiple_outline,
        ctx.getBrandedString(R.string.main_blog_desc),
        text = ctx.getString(R.string.main_blog_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = ABlogActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class FaqDash(val ctx: Context) : Dash(
        DASH_ID_FAQ,
        R.drawable.ic_help_outline,
        ctx.getString(R.string.main_faq_desc),
        text = ctx.getString(R.string.main_faq_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = AFaqActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class FeedbackDash(val ctx: Context) : Dash(
        DASH_ID_FEEDBACK,
        R.drawable.ic_feedback,
        ctx.getBrandedString(R.string.main_feedback_desc),
        text = ctx.getString(R.string.main_feedback_text),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup, false)
        val actor = AFeedbackActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class BugReportDash(val ctx: Context) : Dash(
        DASH_ID_BUG,
        R.drawable.ic_bug,
        ctx.getBrandedString(R.string.main_bug_desc),
        text = ctx.getString(R.string.main_bug_text),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup, false)
        val actor = ABugActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class StatusDash(
        val ctx: Context,
        val enabledStateActor: EnabledStateActor = ctx.di().instance()
) : Dash(
        DASH_ID_STATUS,
        R.drawable.ic_vpn_key,
        ctx.getBrandedString(R.string.main_status_desc)
), IEnabledStateActorListener {

    private val j by lazy { ctx.di().instance<IJournal>() }
    private val ui by lazy { ctx.di().instance<UiState>() }
    private val s by lazy { ctx.di().instance<State>() }

    private var canClick = true

    init {
        finishDeactivating()
        enabledStateActor.listeners.add(this)

        onClick = {
            if (canClick) {
                s.enabled %= !s.enabled()
            }
            true
        }
    }

    override fun startActivating() {
        icon = R.drawable.ic_timer_sand_empty
        text = getStatusText(R.string.main_status_activating, long = false)
        description = ctx.getRandomString(R.array.main_activating, R.string.branding_app_name_short)
        canClick = false
    }

    override fun finishActivating() {
        icon = R.drawable.ic_vpn_key
        text = getStatusText(R.string.main_status_active_recent, long = true)
        description = ctx.getRandomString(R.array.main_active, R.string.branding_app_name_short)
        canClick = true
    }

    override fun startDeactivating() {
        icon = R.drawable.ic_timer_sand_empty
        text = getStatusText(R.string.main_status_deactivating, long = false)
        description = ctx.getBrandedString(R.string.main_status_deactivating)
        canClick = false
    }

    override fun finishDeactivating() {
        icon = R.drawable.ic_key_remove
        text = getStatusText(R.string.main_status_disabled, long = true)
        description = ctx.getRandomString(R.array.main_paused, R.string.branding_app_name_short)
        canClick = true
    }

    private fun getStatusText(status: Int, long: Boolean): String {
        return if (long) {
            ctx.getString(R.string.main_status_long,
                    ctx.getString(status).toLowerCase(),
                    ctx.getString(R.string.branding_app_name_short))
        } else {
            ctx.getString(R.string.main_status_short, ctx.getString(status))
        }
    }
}

class AutoStartDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(
        "main_autostart",
        icon = false,
        description = ctx.getBrandedString(R.string.main_autostart_desc),
        text = ctx.getString(R.string.main_autostart_text),
        isSwitch = true
) {

    override var checked = false
        set(value) { if (field != value) {
            field = value
            s.startOnBoot %= value
            onUpdate.forEach { it() }
        }}

    private var listener: IWhen? = null
    init {
        listener = s.startOnBoot.doOnUiWhenSet().then {
            checked = s.startOnBoot()
        }
    }
}

class DataSavedDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(
    "main_data_saved",
    R.drawable.ic_data_usage,
    ctx.getBrandedString(R.string.main_data_desc)
) {
    private var listener: IWhen? = null
    private var listener2: IWhen? = null
    init {
        updateText()
        listener = s.enabled.doOnUiWhenSet().then { updateText() }
        listener2 = s.tunnelAdsCount.doOnUiWhenSet().then { updateText() }
    }

    private fun updateText() {
        text = if (!s.enabled()) {
            ctx.getString(R.string.main_data_start)
        } else {
            ctx.getString(R.string.main_data_normal, s.tunnelAdsCount() * 0.003f)
        }
    }
}
