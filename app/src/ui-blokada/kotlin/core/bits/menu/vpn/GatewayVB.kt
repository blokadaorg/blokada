package core.bits.menu.vpn

import blocka.BlockaRestModel
import blocka.CurrentAccount
import blocka.CurrentLease
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.accountInactive
import gs.property.I18n
import org.blokada.R
import tunnel.showSnack
import java.util.*

class GatewayVB(
        private val ktx: AndroidKontext,
        private val gateway: BlockaRestModel.GatewayInfo,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update() {
        val cfg = get(CurrentLease::class.java)
        val account = get(CurrentAccount::class.java)

        view?.apply {
            content = Slot.Content(
                    label = "%s (%s)".format(gateway.niceName(), gateway.region),
                    icon = ktx.ctx.getDrawable(
                            when {
                                gateway.overloaded() -> R.drawable.ic_shield_outline
                                gateway.partner() -> R.drawable.ic_shield_plus
                                else -> R.drawable.ic_verified
                            }
                    ),
                    description = i18n.getString(R.string.slot_gateway_description,
                                getLoad(gateway.resourceUsagePercent), gateway.ipv4, gateway.region),
                    switched = gateway.publicKey == cfg.gatewayId
            )

            onSwitch = {
                when {
                    gateway.publicKey == cfg.gatewayId -> {
                        entrypoint.onGatewayDeselected()
                    }
                    account.activeUntil.before(Date()) -> {
                        accountInactive(ktx.ctx)
                        update()
                    }
                    gateway.overloaded() -> {
                        showSnack(R.string.slot_gateway_overloaded)
                        update()
                    }
                    else -> {
                        entrypoint.onGatewaySelected(gateway.publicKey)
                    }
                }
            }
        }
    }

    private fun getLoad(usage: Int): String {
        return i18n.getString(when (usage) {
            in 0..50 -> R.string.slot_gateway_load_low
            else -> R.string.slot_gateway_load_high
        })
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        on(CurrentLease::class.java, this::update)
        update()
    }

    override fun detach(view: SlotView) {
        cancel(CurrentLease::class.java, this::update)
    }
}
