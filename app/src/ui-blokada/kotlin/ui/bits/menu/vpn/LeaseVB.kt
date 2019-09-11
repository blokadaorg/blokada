package ui.bits.menu.vpn

import android.os.Build
import blocka.CurrentAccount
import blocka.blockaVpnMain
import com.github.salomonbrys.kodein.instance
import core.*
import gs.property.I18n
import org.blokada.R
import tunnel.RestModel

class LeaseVB(
        val ktx: AndroidKontext,
        private val lease: RestModel.LeaseInfo,
        val i18n: I18n = ktx.di().instance(),
        val onRemoved: (LeaseVB) -> Unit = {},
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update() {
        val cfg = get(CurrentAccount::class.java)
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
                blockaVpnMain.deleteLease(RestModel.LeaseRequest(
                        accountId = cfg.id,
                        publicKey = lease.publicKey,
                        gatewayId = lease.gatewayId,
                        alias = ""
                ))
                onRemoved(this@LeaseVB)
            }
        }
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        on(CurrentAccount::class.java, this::update)
        update()
    }

    override fun detach(view: SlotView) {
        cancel(CurrentAccount::class.java, this::update)
    }
}
