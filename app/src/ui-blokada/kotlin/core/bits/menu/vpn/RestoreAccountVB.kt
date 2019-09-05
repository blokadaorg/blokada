package core.bits.menu.vpn

import android.content.Intent
import core.*
import org.blokada.R

class RestoreAccountVB(
        private val ktx: AndroidKontext,
        private val modal: ModalManager = modalManager
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_reload.res())
        view.label(R.string.slot_account_action_change_id.res())
        view.onTap {
            modal.openModal()
            ktx.ctx.startActivity(Intent(ktx.ctx, RestoreAccountActivity::class.java))
        }
    }
}

