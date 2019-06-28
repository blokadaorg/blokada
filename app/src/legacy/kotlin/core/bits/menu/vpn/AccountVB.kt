package core.bits.menu.vpn

import android.content.Intent
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.pretty
import gs.property.I18n
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import java.util.*

class AccountVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_account_circle_black_24dp.res())
        view.onTap {
            modal.openModal()
            ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
        }
        update(null)
        ktx.on(BLOCKA_CONFIG, update)
    }

    override fun detach(view: BitView) {
        ktx.cancel(BLOCKA_CONFIG, update)
    }

    private val update = { cfg: BlockaConfig? ->
        view?.apply {
            val isActive = cfg?.activeUntil?.after(Date()) ?: false
            val accountLabel = if (isActive)
                i18n.getString(R.string.slot_account_label_active, cfg!!.activeUntil.pretty(ktx))
            else i18n.getString(R.string.slot_account_label_inactive)

            label(accountLabel.res())

            val stateLabel = if (isActive) R.string.slot_account_action_manage.res()
                else R.string.slot_account_action_manage_inactive.res()
            state(stateLabel)
        }
        Unit
    }
}
