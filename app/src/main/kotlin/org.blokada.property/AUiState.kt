package org.blokada.property

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.environment.Environment
import org.blokada.BuildConfig
import org.blokada.presentation.*
import org.obsolete.KContext
import org.obsolete.newPersistedProperty
import org.obsolete.newProperty

class AUiState(
        private val kctx: KContext,
        private val xx: Environment
) : UiState() {

    private val ctx: Context by xx.instance()

    override val seenWelcome = newPersistedProperty(kctx, APrefsPersistence(ctx, "seenWelcome"),
            { false }
    )

    override val version = newPersistedProperty(kctx, APrefsPersistence(ctx, "version"),
            { BuildConfig.VERSION_CODE }
    )

    override val notifications = newPersistedProperty(kctx, APrefsPersistence(ctx, "notifications"),
            { true }
    )

    override val editUi = newProperty(kctx, { false })

    override val dashes = newPersistedProperty(kctx, ADashesPersistence(ctx), { listOf(
            UpdateDash(ctx).activate(true),
            TunnelDashCountDropped(ctx).activate(true),
            DashFilterBlacklist(ctx).activate(true),
            DashFilterWhitelist(ctx).activate(true),
            NotificationDashOn(ctx).activate(true),
            NotificationDashKeepAlive(ctx).activate(true),
            AutoStartDash(ctx).activate(true),
            ConnectivityDash(ctx).activate(true),
            TunnelDashHostsCount(ctx).activate(true),
            PatronDash(xx).activate(false),
            PatronAboutDash(xx).activate(false),
            DonateDash(xx).activate(false),
            ContributeDash(xx).activate(false),
            NewsDash(xx).activate(false),
            FeedbackDash(xx).activate(false),
            FaqDash(xx).activate(false),
            ChangelogDash(xx).activate(false),
            AboutDash(ctx).activate(false),
            CreditsDash(xx).activate(false),
            CtaDash(xx).activate(false)
    ) })

    override val infoQueue = newProperty(kctx, { listOf<Info>() })

    override val lastSeenUpdateMillis = newPersistedProperty(kctx, APrefsPersistence(ctx, "lastSeenUpdate"),
            { 0L }
    )

    override val showSystemApps = newPersistedProperty(kctx, APrefsPersistence(ctx, "showSystemApps"),
            { true })

}

