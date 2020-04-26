package core.bits.menu.vpn

import android.content.Intent
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.VpnVB
import core.bits.menu.MenuItemVB
import core.bits.menu.MenuItemsVB
import core.bits.menu.SimpleMenuItemVB
import gs.presentation.NamedViewBinder
import org.blokada.R
import ui.StaticUrlWebActivity
import ui.bits.menu.vpn.LeasesDashboardSectionVB

private fun createMenuVpn(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(
        ktx,
        items = listOf(
            LabelVB(ktx, label = R.string.menu_vpn_intro.res()),
            VpnVB(ktx),
            createManageAccountMenuItem(ktx),
            LabelVB(ktx, label = R.string.menu_vpn_tunnel_settings.res()),
            createGatewaysMenuItem(ktx),
            createLeasesMenuItem(ktx),
            LabelVB(ktx, label = R.string.menu_vpn_tunnel_learn_more.res()),
            createWhyVpnMenuItem(ktx),
            SupportVB(ktx)
        ),
        name = R.string.menu_vpn.res()
    )
}

fun createVpnMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(
        ktx,
        label = R.string.menu_vpn.res(),
        icon = R.drawable.ic_shield_plus_outline.res(),
        opens = createMenuVpn(ktx)
    )
}

fun createManageAccountMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(
        ktx,
        label = R.string.menu_vpn_account.res(),
        icon = R.drawable.ic_account_circle_black_24dp.res(),
        opens = createAccountMenu(ktx)
    )
}

fun createGatewaysMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(
        ktx,
        label = R.string.menu_vpn_gateways.res(),
        icon = R.drawable.ic_server.res(),
        opens = GatewaysDashboardSectionVB(ktx)
    )
}

fun createLeasesMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(
        ktx,
        label = R.string.menu_vpn_leases.res(),
        icon = R.drawable.ic_device.res(),
        opens = LeasesDashboardSectionVB(ktx)
    )
}

fun createWhyVpnMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val whyPage = ktx.di().instance<Pages>().vpn
    return SimpleMenuItemVB(ktx,
        label = R.string.menu_vpn_intro_button.res(),
        icon = R.drawable.ic_info.res(),
        arrow = false,
        action = {
            modalManager.openModal()
            ktx.ctx.startActivity(Intent(ktx.ctx, StaticUrlWebActivity::class.java).apply {
                putExtra(WebViewActivity.EXTRA_URL, whyPage().toExternalForm())
            })
        }
    )
}

private fun createAccountMenu(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(
        ktx,
        items = listOf(
            AccountVB(ktx),
            if (Product.current(ktx.ctx) == Product.FULL) ManageAccountVB(ktx) else null,
            RestoreAccountVB(ktx),
            createWhyVpnMenuItem(ktx),
            LabelVB(ktx, label = R.string.menu_vpn_info_account_label.res()),
            TextPointVB(ktx, label = R.string.menu_vpn_info_account_line1.res()),
            TextPointVB(ktx, label = R.string.menu_vpn_info_account_line2.res()),
            TextPointVB(ktx, label = R.string.menu_vpn_info_account_line3.res()),
            TextPointVB(ktx, label = R.string.menu_vpn_info_account_line4.res())
        ).filterNotNull(),
        name = R.string.menu_vpn_account.res()
    )
}

