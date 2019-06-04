package core

import android.content.Context
import android.content.Intent
import com.github.michaelbull.result.get
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.presentation.ViewBinder
import gs.property.Version
import org.blokada.BuildConfig

data class SlotsSeenStatus(
        val intro: Boolean = false,
        val telegram: Boolean = false,
        val blog: Boolean = false,
        val updated: Int = BuildConfig.VERSION_CODE,
        val cta: Int = 0,
        val donate: Int = 0
)

class HomeDashboardSectionVB(
        val ktx: AndroidKontext,
        val ctx: Context = ktx.ctx,
        val version: Version = ktx.di().instance(),
        val welcome: Welcome = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    val markAsSeen = {
        val removed = items[0]
        markAsSeen(removed)
        items = items.subList(1, items.size)
        view?.set(items)
        slotMutex.detach()
    }

    val intro: IntroVB = IntroVB(ctx.ktx("InfoSlotVB"), onTap = slotMutex.openOneAtATime,
            onRemove = markAsSeen)
    val updated = UpdatedVB(ctx.ktx("UpdatedVB"), onTap = slotMutex.openOneAtATime, onRemove = markAsSeen)
    val obsolete = ObsoleteVB(ctx.ktx("ObsoleteVB"), onTap = slotMutex.openOneAtATime)
    val cleanup = CleanupVB(ctx.ktx("CleanupVB"), onTap = slotMutex.openOneAtATime)
    val donate = DonateVB(ctx.ktx("DonateVB"), onTap = slotMutex.openOneAtATime, onRemove = markAsSeen)
    val cta = CtaVB(ctx.ktx("CtaVB"), onTap = slotMutex.openOneAtATime, onRemove = markAsSeen)
    val blog = BlogVB(ctx.ktx("BlogVB"), onTap = slotMutex.openOneAtATime, onRemove = markAsSeen)
    val telegram = TelegramVB(ctx.ktx("TelegramVB"), onTap = slotMutex.openOneAtATime, onRemove = markAsSeen)

    private var items = listOf<ViewBinder>(
            AppStatusVB(ctx.ktx("AppStatusSlotVB"), onTap = slotMutex.openOneAtATime),
            HomeNotificationsVB(ctx.ktx("NotificationsVB"), onTap = slotMutex.openOneAtATime),
            HelpVB(ctx.ktx("HelpVB"), onTap = slotMutex.openOneAtATime),
            ProtectionVB(ctx.ktx("ProtectionVB"), onTap = slotMutex.openOneAtATime)
    )

    override fun attach(view: VBListView) {
        val slot = decideOnSlot()
        if (slot != null) items = listOf(slot) + items
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

    private fun markAsSeen(slot: ViewBinder) {
        val cfg = Persistence.slots.load().get()!!
        val newCfg = when {
            slot == cta -> cfg.copy(cta = cfg.cta + 1)
            slot == donate -> cfg.copy(donate = cfg.donate + 1)
            slot == blog -> cfg.copy(blog = true)
            slot == updated -> cfg.copy(updated = BuildConfig.VERSION_CODE)
            slot == telegram -> cfg.copy(telegram = true)
            slot == intro -> cfg.copy(intro = true)
            else -> cfg
        }
        Persistence.slots.save(newCfg)
    }

    private fun decideOnSlot(): ViewBinder? {
        val cfg = Persistence.slots.load().get()!!
        return when {
            !cfg.intro -> intro
            BuildConfig.VERSION_CODE > cfg.updated -> updated
            version.obsolete() -> obsolete
            getInstalledBuilds().size > 1 -> cleanup
            !cfg.telegram -> telegram
            !cfg.blog -> blog
            cfg.cta < cfg.donate -> cta
            else -> donate
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
}

class SlotStatusPersistence {
    val load = { ->
        Result.of { core.Persistence.paper().read<SlotsSeenStatus>("slots:status", SlotsSeenStatus()) }
    }
    val save = { slots: SlotsSeenStatus ->
        Result.of { core.Persistence.paper().write("slots:status", slots) }
    }
}
