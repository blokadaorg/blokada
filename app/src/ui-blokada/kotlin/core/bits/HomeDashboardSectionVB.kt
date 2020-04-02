package core.bits

import android.content.Context
import android.content.Intent
import android.net.Uri
import blocka.BlockaVpnState
import blocka.CurrentAccount
import com.github.michaelbull.result.get
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.isLandscape
import gs.environment.inject
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.presentation.ViewBinder
import gs.property.I18n
import gs.property.Repo
import gs.property.Version
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import org.blokada.BuildConfig
import org.blokada.R
import tunnel.ExtendedRequestLog
import tunnel.TunnelConfig
import ui.StaticUrlWebActivity
import update.DOWNLOAD_COMPLETE
import update.DOWNLOAD_FAIL
import update.UpdateCoordinator
import java.net.URL
import java.util.*


val REFRESH_HOME = "REFRESH_HOME".newEvent()

data class SlotsSeenStatus(
        val intro: Boolean = false,
        val telegram: Boolean = false,
        val blog: Boolean = false,
        val updated: Int = 0,
        val cta: Int = 0,
        val donate: Int = 0,
        val blokadaOrg: Boolean = false
)

class SlotStatusPersistence {
    val load = { ->
        Result.of { Persistence.paper().read<SlotsSeenStatus>("slots:status", SlotsSeenStatus()) }
    }
    val save = { slots: SlotsSeenStatus ->
        Result.of { Persistence.paper().write("slots:status", slots) }
    }
}

class HomeDashboardSectionVB(
        val ktx: AndroidKontext,
        val ctx: Context = ktx.ctx,
        val version: Version = ktx.di().instance(),
        val welcome: Welcome = ktx.di().instance(),
        val repo: Repo = ktx.di().instance(),
        override val name: Resource = R.string.panel_section_home.res()
) : ListViewBinder(), NamedViewBinder {

    override fun attach(view: VBListView) {
        on(CurrentAccount::class.java, this::update)
        on(REFRESH_HOME, this::forceUpdate, recentValue = false)
        update()
        if (isLandscape(ktx.ctx)) {
            view.enableLandscapeMode(staggered = true)
            view.set(items)
        } else view.set(items)
    }

    override fun detach(view: VBListView) {
        cancel(CurrentAccount::class.java, this::update)
        cancel(REFRESH_HOME, this::forceUpdate)
    }

    private val slotPosition = 1

    private fun forceUpdate() {
        async {
            markAnnouncementAsUnseen()
            requestAnnouncement()
            async(UI) { update() }
        }
    }

    private fun update() {
        val cfg = get(CurrentAccount::class.java)
        view?.run {
            if (added != null) {
                val slot = items[slotPosition]
                items = items - slot
                remove(slot)
                added = null
            }

            val noSubscription = cfg.activeUntil.before(Date())
            val (slot, name) = decideOnSlot(noSubscription)
            if (slot != null && added == null) {
                items = items.subList(0, slotPosition) + listOf(slot) + items.subList(slotPosition, items.size)
                add(slot, slotPosition)
                added = name

                if (slot is SimpleByteVB) slot.onTapped = {
                    // Remove this slot
                    markAsSeen()

                    if (!slot.shouldKeepAfterTap) {
                        items = items - slot
                        remove(slot)
                        added = null
                    }
                }
            } else {
                if (isLandscape(ktx.ctx)) {
                    enableLandscapeMode(staggered = true)
                    set(items)
                } else {
                    set(items)
                }
            }
        }
    }

    private var items = listOf<ViewBinder?>(
            MasterSwitchVB(ktx),
            if (Product.current(ktx.ctx) == Product.GOOGLE) null else AdsBlockedVB(ktx),
            ActiveDnsVB(ktx),
            VpnStatusVB(ktx),
            //if (Product.current(ktx.ctx) == Product.GOOGLE) ShareInGoogleFlavorVB(ktx) else ShareVB(ktx),
            if (Product.current(ktx.ctx) == Product.GOOGLE) BlokadaSlimVB() else null
    ).filterNotNull()

    private var added: OneTimeByte? = null
    private val oneTimeBytes = createOneTimeBytes(ktx)

    private fun markAsSeen() {
        if (added == OneTimeByte.ANNOUNCEMENT) {
            markAnnouncementAsSeen()
        } else {
            val cfg = Persistence.slots.load().get()!!
            val newCfg = when (added) {
                OneTimeByte.UPDATED -> cfg.copy(updated = BuildConfig.VERSION_CODE)
                OneTimeByte.DONATE -> cfg.copy(donate = BuildConfig.VERSION_CODE)
                else -> cfg
            }
            Persistence.slots.save(newCfg)
        }
    }

    private fun decideOnSlot(noSubscription: Boolean): Pair<ViewBinder?, OneTimeByte?> {
        val cfg = Persistence.slots.load().get()
        val name = if (cfg == null) null else when {
            isLandscape(ktx.ctx) -> null
            isUpdate(ctx, repo.content().newestVersionCode) -> OneTimeByte.UPDATE_AVAILABLE
            hasNewAnnouncement() -> OneTimeByte.ANNOUNCEMENT
            BuildConfig.VERSION_CODE > cfg.updated -> OneTimeByte.UPDATED
            Product.current(ktx.ctx) == Product.FULL && (BuildConfig.VERSION_CODE > cfg.donate)
                    && noSubscription -> OneTimeByte.DONATE
            version.obsolete() -> OneTimeByte.OBSOLETE
            getInstalledBuilds().size > 1 -> OneTimeByte.CLEANUP
            else -> null
        }
        return oneTimeBytes[name]?.invoke() to name
    }
}

class VpnVB(
        private val ktx: AndroidKontext,
        private val tunnelState: Tunnel = ktx.di().instance()
) : BitVB() {

    override fun attach(view: BitView) {
        on(BlockaVpnState::class.java, this::update)
        update()
    }

    override fun detach(view: BitView) {
        cancel(BlockaVpnState::class.java, this::update)
    }

    private fun update() {
        val config = get(BlockaVpnState::class.java)
        view?.apply {
            onSwitch { enable ->
                if (enable && !tunnelState.enabled()) tunnelState.enabled %= true
                entrypoint.onVpnSwitched(enable)
            }

            if (!tunnelState.enabled()) {
                label(R.string.home_blokada_disabled.res())
                icon(R.drawable.ic_shield_plus_outline.res())
                switch(false)
            } else {
                if (config.enabled) {
                    label(R.string.home_vpn_enabled.res())
                    icon(R.drawable.ic_shield_plus.res(), color = R.color.switch_on.res())
                } else {
                    label(R.string.home_vpn_disabled.res())
                    icon(R.drawable.ic_shield_plus_outline.res())
                }
                switch(config.enabled)
            }
        }
        Unit
    }
}

class Adblocking2VB(
        private val ktx: AndroidKontext,
        private val tunnelState: Tunnel = ktx.di().instance()
) : BitVB() {

    override fun attach(view: BitView) {
        on(TunnelConfig::class.java, this::update)
        on(BlockaVpnState::class.java, this::update)
        update()
    }

    override fun detach(view: BitView) {
        cancel(TunnelConfig::class.java, this::update)
        cancel(BlockaVpnState::class.java, this::update)
    }

    private fun update() {
        val config = get(TunnelConfig::class.java)
        val blockaVpnState = get(BlockaVpnState::class.java)

        view?.apply {
            onSwitch { enable ->
                if (enable && !tunnelState.enabled()) tunnelState.enabled %= true
                entrypoint.onSwitchAdblocking(enable)
            }

            if (!tunnelState.enabled()) {
                label(R.string.home_blokada_disabled.res())
                icon(R.drawable.ic_blocked.res())
                switch(false)
            } else {
                if (config.adblocking) {
                    label(R.string.home_adblocking_enabled.res())
                    icon(R.drawable.ic_blocked.res(), color = R.color.switch_on.res())
                } else {
                    label(R.string.home_adblocking_disabled.res())
                    icon(R.drawable.ic_show.res())
                }
                switch(config.adblocking)
            }
        }
        Unit
    }

}

open class SimpleByteVB(
        private val ktx: AndroidKontext,
        private val label: Resource,
        private val description: Resource,
        private val icon: Resource? = R.drawable.ic_bell_ring_outline.res(),
        val shouldKeepAfterTap: Boolean = false,
        private val onTap: (ktx: AndroidKontext, view: ByteView) -> Unit,
        private val onLongTap: ((ktx: AndroidKontext) -> Unit)? = null,
        private val beforeTap: (view: ByteView) -> Unit = {},
        var onTapped: (view: ByteView) -> Unit = {}
) : ByteVB() {
    override fun attach(view: ByteView) {
        view.icon(icon)
        view.label(label)
        view.arrow(null)
        view.state(description, smallcap = false)
        view.onTap {
            beforeTap(view)
            onTapped(view)
            async {
                delay(1000)
                async(UI) {
                    onTap(ktx, view)
                }
            }
        }
        if (onLongTap != null) {
            view.onLongTap {
                onLongTap.invoke(ktx)
            }
        }
    }
}

enum class OneTimeByte {
    CLEANUP, UPDATED, OBSOLETE, DONATE, UPDATE_AVAILABLE, ANNOUNCEMENT, BLOKADAORG, BLOKADAPLUS
}

fun createOneTimeBytes(
        ktx: AndroidKontext
) = mapOf(
        OneTimeByte.CLEANUP to { CleanupVB(ktx) },
        OneTimeByte.UPDATED to { SimpleByteVB(ktx,
                label = R.string.home_whats_new.res(),
                description = R.string.slot_updated_desc.res(),
                onTap = { ktx, _ ->
                    val pages: Pages = ktx.di().instance()
                    modalManager.openModal()
                    ktx.ctx.startActivity(Intent(ktx.ctx, StaticUrlWebActivity::class.java).apply {
                        putExtra(WebViewActivity.EXTRA_URL, pages.updated().toExternalForm())
                    })
                }
        )},
        OneTimeByte.OBSOLETE to { SimpleByteVB(ktx,
                label = R.string.home_update_required.res(),
                description = R.string.slot_obsolete_desc.res(),
                onTap = { ktx, _ ->
                    val pages: Pages = ktx.di().instance()
                    openWebContent(ktx.ctx, pages.download())
                }
        )},
        OneTimeByte.DONATE to { SimpleByteVB(ktx,
                label = R.string.home_donate.res(),
                description = R.string.slot_donate_desc.res(),
                icon = R.drawable.ic_heart_box.res(),
                onTap = { ktx, _ ->
                    val pages: Pages = ktx.di().instance()
                    openWebContent(ktx.ctx, pages.donate())
                }
        )},
        OneTimeByte.UPDATE_AVAILABLE to { UpdateAvailableVB(ktx) },
        OneTimeByte.ANNOUNCEMENT to { SimpleByteVB(ktx,
                label = getAnnouncementContent().first.res(),
                description = getAnnouncementContent().second.res(),
                icon = R.drawable.ic_bell_ring_outline.res(),
                onTap = { ktx, _ ->
                    openWebContent(ktx.ctx, URL(getAnnouncementUrl()))
                }
        ) },
        OneTimeByte.BLOKADAORG to { SimpleByteVB(ktx,
                icon = R.drawable.ic_baby_face_outline.res(),
                label = R.string.home_blokadaorg.res(),
                description = R.string.home_blokadaorg_state.res(),
                onTap  = { ktx, _ ->
                    openInExternalBrowser(ktx.ctx, URL("https://blokada.org/#download"))
                }
        )},
        OneTimeByte.BLOKADAPLUS to { SimpleByteVB(ktx,
                label = "Get $1 for yourself".res(),
                description = "Refer a friend to Blokada Tunnel".res(),
                onTap  = { ktx, _ ->
                }
        )}
)

private var updateNextLink = 0

class UpdateAvailableVB(
        val ktx: AndroidKontext,
        val i18n: I18n = ktx.di().instance(),
        repo: Repo = ktx.di().instance(),
        updateCoordinator: UpdateCoordinator = ktx.di().instance()
): SimpleByteVB(ktx,
        label = R.string.update_notification_title.res(),
        description = i18n.getString(R.string.update_notification_text, repo.content().newestVersionName).res(),
        icon = R.drawable.ic_new_releases.res(),
        shouldKeepAfterTap = true,
        beforeTap = { view ->
            view.label(R.string.update_starting.res())
        },
        onTap = { ktx, view ->
            updateCoordinator.start(repo.content().downloadLinks)
        },
        onLongTap = {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.data = Uri.parse(repo.content().downloadLinks[updateNextLink].toString())

            ktx.ctx.startActivity(intent)

            updateNextLink = updateNextLink++ % repo.content().downloadLinks.size
        }
) {
    private fun refresh(progress: Int) {
        val label = when (progress) {
            DOWNLOAD_COMPLETE -> i18n.getString(R.string.update_complete)
            DOWNLOAD_FAIL -> i18n.getString(R.string.update_failed)
            else -> i18n.getString(R.string.update_progress, progress)
        }
        val info = when (progress) {
            DOWNLOAD_COMPLETE -> i18n.getString(R.string.update_instruction_failed)
            DOWNLOAD_FAIL -> i18n.getString(R.string.update_instruction_failed)
            else -> i18n.getString(R.string.update_instruction)
        }
        view?.label(label.res())
        view?.state(info.res())
    }

    override fun attach(view: ByteView) {
        super.attach(view)
        on(update.EVENT_UPDATE_PROGRESS, this::refresh)
    }

    override fun detach(view: ByteView) {
        super.detach(view)
        cancel(update.EVENT_UPDATE_PROGRESS, this::refresh)
    }
}


class ShareVB(
        val ktx: AndroidKontext,
        private val tunnelEvents: Tunnel = ktx.di().instance()
) : ByteVB() {
    override fun attach(view: ByteView) {
        view.run {
            icon(null)
            arrow(R.drawable.ic_share.res())
            label(R.string.home_share.res())
            state(R.string.home_share_state.res())
//            onArrowTap { share() }
            onArrowTap { share() }
        }
    }

    fun share() {
        try {
            val shareIntent: Intent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_TEXT, getMessage(ktx.ctx,
                        ExtendedRequestLog.dropStart, Format.counter(ExtendedRequestLog.dropCount)))
                type = "text/plain"
            }
            ktx.ctx.startActivity(Intent.createChooser(shareIntent,
                    ktx.ctx.getText(R.string.slot_dropped_share_title)))
        } catch (e: Exception) {}
    }

    private fun getMessage(ctx: Context, timeStamp: Long, dropCount: String): String {
        var elapsed: Long = System.currentTimeMillis() - timeStamp
        elapsed /= 60000
        if (elapsed < 120) {
            return ctx.resources.getString(R.string.social_share_body_minute, dropCount, elapsed)
        }
        elapsed /= 60
        if (elapsed < 48) {
            return ctx.resources.getString(R.string.social_share_body_hour, dropCount, elapsed)
        }
        elapsed /= 24
        if (elapsed < 28) {
            return ctx.resources.getString(R.string.social_share_body_day, dropCount, elapsed)
        }
        elapsed /= 7
        return ctx.resources.getString(R.string.social_share_body_week, dropCount, elapsed)
    }

}

class ShareInGoogleFlavorVB(
        val ktx: AndroidKontext,
        private val dns: Dns = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance()
) : ByteVB() {
    override fun attach(view: ByteView) {
        view.run {
            icon(null)
            arrow(R.drawable.ic_share.res())
            label(R.string.home_share.res())
            state(R.string.home_share_state_google.res())
//            onArrowTap { share() }
            onArrowTap { share() }
        }
    }

    private fun share() {
        try {
            val msg = i18n.getString(R.string.home_share_msg_google)
            val shareIntent: Intent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_TEXT, msg)
                type = "text/plain"
            }
            ktx.ctx.startActivity(Intent.createChooser(shareIntent,
                    ktx.ctx.getText(R.string.slot_dropped_share_title)))
        } catch (e: Exception) {}
    }

}

class BlokadaSlimVB: ByteVB() {
    override fun attach(view: ByteView) {
        view.run {
            icon(null)
            arrow(R.drawable.ic_download.res())
            label(R.string.home_blokadaorg.res())
            state(R.string.home_blokadaorg_state.res())
            onTap {
                val pages: Pages = view.context.inject().instance()
                openInExternalBrowser(context, pages.chat())
            }
        }
    }
}
