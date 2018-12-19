package core

import adblocker.LoggerVB
import android.content.Context
import android.support.v4.content.ContextCompat
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance
import gs.presentation.LayoutViewBinder
import gs.presentation.WebDash
import org.blokada.R

data class DashboardSection(
        val nameResId: Int,
        val dash: gs.presentation.ViewBinder,
        val subsections: List<DashboardNavItem> = emptyList()
)

data class DashboardNavItem(
        val iconResId: Int,
        val nameResId: Int,
        val dash: gs.presentation.ViewBinder
)

fun createDashboardSections(ktx: AndroidKontext): List<DashboardSection> {
    val di = ktx.di()
    val pages: Pages = di.instance()

    var sections = emptyList<DashboardSection>()

    sections += DashboardSection(
            nameResId = R.string.panel_section_apps,
            dash = AppsDashboardSectionVB(ktx.ctx),
            subsections = listOf(
                    DashboardNavItem(R.drawable.ic_apps, R.string.panel_section_apps_all, AllAppsDashboardSectionVB(ktx.ctx, system = false)),
                    DashboardNavItem(R.drawable.ic_apps, R.string.panel_section_apps_system, AllAppsDashboardSectionVB(ktx.ctx, system = true))
            )
    )

    sections += DashboardSection(
            nameResId = R.string.panel_section_home,
            dash = HomeDashboardSectionVB(ktx),
            subsections = listOf(
                    DashboardNavItem(
                            iconResId = R.drawable.ic_help_outline,
                            nameResId = R.string.panel_section_home_start,
//                            dash = StartViewBinder(ktx,
//                                    currentAppVersion = BuildConfig.VERSION_CODE,
//                                    afterWelcome = {}
//                            )
                            dash = StartDashboardSectionVB(ktx)
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_server,
                            nameResId = R.string.panel_section_home_gateways,
                            dash = GatewaysDashboardSectionVB(ktx.ctx.ktx("gateways"))
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_help_outline,
                            nameResId = R.string.panel_section_home_help,
                            dash = WebDash(LazyKodein(ktx.di), pages.help,
                                    reloadOnError = true, javascript = true)
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_heart_box,
                            nameResId = R.string.main_donate_text,
                            dash = WebDash(LazyKodein(ktx.di), pages.donate,
                            reloadOnError = true, javascript = true)
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_info,
                            nameResId = R.string.main_credits,
                            dash = WebDash(LazyKodein(ktx.di), pages.credits,
                            reloadOnError = true, javascript = true))
            )
    )

    sections += DashboardSection(
            nameResId = R.string.panel_section_ads,
            dash = AdsDashboardSectionVB(ktx),
            subsections = listOf(
                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_blacklist, BlacklistDashboardSection(ktx)),
                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_whitelist, WhitelistDashboardSectionVB(ktx)),
                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_lists, FiltersSectionVB(ktx)),
                    DashboardNavItem(R.drawable.ic_apps, R.string.panel_section_ads_log, AdsLogVB(ktx)),
                    DashboardNavItem(R.drawable.ic_tune, R.string.panel_section_ads_settings, StaticItemsListVB(listOf(
                            FiltersListControlVB(ktx, onTap = defaultOnTap),
                            DownloadListsVB(ktx, onTap = defaultOnTap),
                            ListDownloadFrequencyVB(ktx, onTap = defaultOnTap),
                            DownloadOnWifiVB(ktx, onTap = defaultOnTap)
                    )))
            )
    )

    sections += DashboardSection(
            nameResId = R.string.panel_section_advanced,
            dash = AdvancedDashboardSectionVB(ktx.ctx),
            subsections = listOf(
                    DashboardNavItem(R.drawable.ic_server, R.string.panel_section_advanced_dns, DnsDashboardSection(ktx.ctx)),
                    DashboardNavItem(R.drawable.ic_tune, R.string.panel_section_ads_settings, StaticItemsListVB(listOf(
                            LoggerVB(ktx, onTap = defaultOnTap),
                            DnsListControlVB(ktx, onTap = defaultOnTap),
                            StorageLocationVB(ktx, onTap = defaultOnTap),
                            NotificationsVB(ktx, onTap = defaultOnTap),
                            StartOnBootVB(ktx, onTap = defaultOnTap),
                            KeepAliveVB(ktx, onTap = defaultOnTap),
                            WatchdogVB(ktx, onTap = defaultOnTap),
                            PowersaveVB(ktx, onTap = defaultOnTap),
                            DnsFallbackVB(ktx, onTap = defaultOnTap),
                            ReportVB(ktx, onTap = defaultOnTap)
                    ))),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_earth,
                            nameResId = R.string.main_blog_text,
                            dash = WebDash(LazyKodein(ktx.di), pages.news,
                                    forceEmbedded = true, reloadOnError = true, javascript = true)
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_feedback,
                            nameResId = R.string.main_feedback_text,
                            dash = LayoutViewBinder(R.layout.dash_placeholder)
                    ),
                    DashboardNavItem(
                            iconResId = R.drawable.ic_code_tags,
                            nameResId = R.string.main_changelog,
                            dash = WebDash(LazyKodein(ktx.di), pages.changelog,
                                    reloadOnError = true, javascript = true))
            )
    )

    return sections
}

class DashboardNavItemView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    var iconResId: Int = 0
        set(value) {
            field = value
            iconView.setImageResource(value)
        }

    var text: String = ""
        set(value) {
            field = value
            counterTextView.text = value
        }

    private val iconView by lazy { findViewById<ImageView>(R.id.icon) }
    private val counterTextView by lazy { findViewById<TextView>(R.id.counter_text) }

    override fun onFinishInflate() {
        super.onFinishInflate()
        hideText()
    }

    fun showText() {
        iconView.animate().scaleX(1f)
                .scaleY(1f).setDuration(200)
                .withEndAction( {
                    counterTextView.visibility = View.VISIBLE
                    iconView.setColorFilter(active)
                } )
                .start()
    }

    val active = ContextCompat.getColor(context, R.color.colorActive)
    val inactive = ContextCompat.getColor(context, R.color.colorActive)

    fun hideText() {
        iconView.setColorFilter(inactive)
        counterTextView.visibility = View.INVISIBLE
        iconView.animate().scaleX(1.1f).scaleY(1.1f)
                .setDuration(200)
                .start()
    }
}
