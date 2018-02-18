package org.blokada.property

import org.obsolete.KContext
import org.obsolete.newPersistedProperty
import android.content.Context
import org.obsolete.newProperty
import org.blokada.BuildConfig
import org.blokada.presentation.*

class AUiState(
        private val ctx: Context,
        private val kctx: KContext
) : UiState() {

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
            TunnelDashAdsBlocked(ctx).activate(true),
            DashFilterBlacklist(ctx).activate(true),
            DashFilterWhitelist(ctx).activate(true),
            NotificationDashOn(ctx).activate(true),
            NotificationDashKeepAlive(ctx).activate(true),
            AutoStartDash(ctx).activate(true),
            ConnectivityDash(ctx).activate(true),
            TunnelDashHostsCount(ctx).activate(true),
            PatronDash(ctx).activate(false),
            PatronAboutDash(ctx).activate(false),
            DonateDash(ctx).activate(false),
            ContributeDash(ctx).activate(false),
            BlogDash(ctx).activate(false),
            FeedbackDash(ctx).activate(false),
            FaqDash(ctx).activate(false).activate(false),
            AboutDash(ctx).activate(false)
    ) })

    override val infoQueue = newProperty(kctx, { listOf<Info>() })

    override val lastSeenUpdateMillis = newPersistedProperty(kctx, APrefsPersistence(ctx, "lastSeenUpdate"),
            { 0L }
    )

    override val showSystemApps = newPersistedProperty(kctx, APrefsPersistence(ctx, "showSystemApps"),
            { true })

}

