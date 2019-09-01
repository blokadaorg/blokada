package ui.bits.menu.vpn

import android.os.Build
import com.github.salomonbrys.kodein.instance
import core.AndroidKontext
import core.Slot
import core.SlotVB
import core.SlotView
import gs.property.I18n
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import tunnel.RestModel
import tunnel.deleteLease

class LeaseVB(
        val ktx: AndroidKontext,
        private val lease: RestModel.LeaseInfo,
        val i18n: I18n = ktx.di().instance(),
        val onRemoved: (LeaseVB) -> Unit = {},
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update(cfg: BlockaConfig) {
        val currentDevice = lease.publicKey == cfg.publicKey
        view?.apply {
            content = Slot.Content(
                    label = if (currentDevice)
                        i18n.getString(R.string.slot_lease_name_current, "%s-%s".format(
                                Build.MANUFACTURER, Build.DEVICE
                        ))
                        else lease.niceName(),
                    icon = ktx.ctx.getDrawable(R.drawable.ic_device),
                    description = if (currentDevice) {
                        i18n.getString(R.string.slot_lease_description_current, lease.publicKey)
                    } else {
                        i18n.getString(R.string.slot_lease_description, lease.publicKey)
                    },
                    action1 = if (currentDevice) null else ACTION_REMOVE
            )

            onRemove = {
                deleteLease(ktx, BlockaConfig(
                        accountId = cfg.accountId,
                        publicKey = lease.publicKey,
                        gatewayId = lease.gatewayId
                ))
                onRemoved(this@LeaseVB)
            }
        }
    }

    private val onConfig = { cfg: BlockaConfig ->
        update(cfg)
        Unit
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        ktx.on(BLOCKA_CONFIG, onConfig)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, onConfig)
    }
}
