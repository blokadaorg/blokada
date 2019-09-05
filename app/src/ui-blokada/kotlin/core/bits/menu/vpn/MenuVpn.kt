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

private fun createMenuVpn(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                LabelVB(ktx, label = R.string.menu_vpn_intro.res()),
                VpnVB(ktx),
                createWhyVpnMenuItem(ktx),
                LabelVB(ktx, label = R.string.menu_vpn_account_label.res()),
                createManageAccountMenuItem(ktx),
                LabelVB(ktx, label = R.string.menu_vpn_gateways_label.res()),
                createGatewaysMenuItem(ktx)
            ),
            name = R.string.menu_vpn.res()
    )
}

fun createVpnMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.menu_vpn.res(),
            icon = R.drawable.ic_shield_key_outline.res(),
            opens = createMenuVpn(ktx)
    )
}

fun createManageAccountMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.menu_vpn_account.res(),
            icon = R.drawable.ic_account_circle_black_24dp.res(),
            opens = createAccountMenu(ktx)
    )
}

fun createGatewaysMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.menu_vpn_gateways.res(),
            icon = R.drawable.ic_server.res(),
            opens = GatewaysDashboardSectionVB(ktx)
    )
}

fun createWhyVpnMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val whyPage = ktx.di().instance<Pages>().vpn
    return SimpleMenuItemVB(ktx,
            label = R.string.menu_vpn_intro_button.res(),
            icon = R.drawable.ic_help_outline.res(),
            action = {
                modalManager.openModal()
                ktx.ctx.startActivity(Intent(ktx.ctx, WebViewActivity::class.java).apply {
                    putExtra(WebViewActivity.EXTRA_URL, whyPage().toExternalForm())
                })
            }
    )
}

private fun createAccountMenu(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.menu_vpn_manage_subscription.res()),
                    AccountVB(ktx),
                    LabelVB(ktx, label = R.string.menu_vpn_account_secret.res()),
                    CopyAccountVB(ktx),
                    LabelVB(ktx, label = R.string.menu_vpn_restore_label.res()),
                    RestoreAccountVB(ktx)
            ),
            name = R.string.menu_vpn_account.res()
    )
}
