package core

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.github.salomonbrys.kodein.instance
import core.bits.AdsDashboardSectionVB
import core.bits.Home2DashboardSectionVB
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createDashboardSections(ktx: AndroidKontext): List<NamedViewBinder> {
    val di = ktx.di()
    val pages: Pages = di.instance()

    return listOf(
            Home2DashboardSectionVB(ktx),
            AdsDashboardSectionVB(ktx)
    )

//    var commonSubsections = listOf(
//            DashboardNavItem(
//                    iconResId = R.drawable.ic_help_outline,
//                    nameResId = R.string.panel_section_home_start,
////                            dash = StartViewBinder(ktx,
////                                    currentAppVersion = BuildConfig.VERSION_CODE,
////                                    afterWelcome = {}
////                            )
//                    dash = MenuDashboardSectionVB(ktx)
//            )//,
////            DashboardNavItem(
////                    iconResId = R.drawable.ic_help_outline,
////                    nameResId = R.string.panel_section_home_start,
//////                            dash = StartViewBinder(ktx,
//////                                    currentAppVersion = BuildConfig.VERSION_CODE,
//////                                    afterWelcome = {}
//////                            )
////                    dash = GatewaysDashboardSectionVB(ktx)
////            ),
////            DashboardNavItem(R.drawable.ic_server, R.string.panel_section_advanced_dns, DnsDashboardSection(ktx.ctx))
//    )
//
//    var sections = emptyList<DashboardSection>()
//
//    sections += DashboardSection(
//            nameResId = R.string.panel_section_home,
//            dash = Home2DashboardSectionVB(ktx)
//    )
//
//    sections += DashboardSection(
//            nameResId = R.string.panel_section_ads,
//            dash = AdsDashboardSectionVB(ktx)
////            subsections = listOf(
////                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_log, AdsLogVB(ktx))
////                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_blacklist, BlacklistDashboardSection(ktx)),
////                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_whitelist, WhitelistDashboardSectionVB(ktx)),
////                    DashboardNavItem(R.drawable.ic_block, R.string.panel_section_ads_lists, FiltersSectionVB(ktx)),
////                    DashboardNavItem(R.drawable.ic_apps, R.string.panel_section_apps_all, AllAppsDashboardSectionVB(ktx.ctx, system = false)),
////                    DashboardNavItem(R.drawable.ic_apps, R.string.panel_section_apps_system, AllAppsDashboardSectionVB(ktx.ctx, system = true))
////            )
//    )
//
////    sections += DashboardSection(
////            nameResId = R.string.panel_section_advanced,
////            dash = AdvancedDashboardSectionVB(ktx),
////            subsections = listOf(
////                    DashboardNavItem(R.drawable.ic_tune, R.string.panel_section_advanced_settings, StaticItemsListVB(listOf(
////                            LabelVB(labelResId = R.string.label_basic),
////                            StartOnBootVB(ktx, onTap = defaultOnTap),
////                            StorageLocationVB(ktx, onTap = defaultOnTap),
////                            NotificationsVB(ktx, onTap = defaultOnTap),
////                            LabelVB(labelResId = R.string.label_filters),
////                            AdblockingVB(ktx, onTap = defaultOnTap),
////                            FiltersListControlVB(ktx, onTap = defaultOnTap),
////                            DownloadListsVB(ktx, onTap = defaultOnTap),
////                            ListDownloadFrequencyVB(ktx, onTap = defaultOnTap),
////                            DownloadOnWifiVB(ktx, onTap = defaultOnTap),
////                            LabelVB(labelResId = R.string.label_dns),
////                            DnsListControlVB(ktx, onTap = defaultOnTap),
////                            DnsFallbackVB(ktx, onTap = defaultOnTap),
////                            LabelVB(labelResId = R.string.label_advanced),
////                            BackgroundAnimationVB(ktx, onTap = defaultOnTap),
////                            LoggerVB(ktx, onTap = defaultOnTap),
////                            KeepAliveVB(ktx, onTap = defaultOnTap),
////                            WatchdogVB(ktx, onTap = defaultOnTap),
////                            PowersaveVB(ktx, onTap = defaultOnTap),
////                            ReportVB(ktx, onTap = defaultOnTap)
////                    )))
////            )
////    )
//
//    return sections
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
