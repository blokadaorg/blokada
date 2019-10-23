package core.bits.menu.vpn

import android.content.Intent
import blocka.BoringtunLoader
import core.*
import org.blokada.R
import tunnel.showSnack

class ManageAccountVB(
        private val ktx: AndroidKontext,
        private val modal: ModalManager = modalManager
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_account_circle_black_24dp.res())
        view.label("Manage subscription".res())
        update()
    }

    override fun detach(view: BitView) {
    }

    private fun update() {
        view?.apply {
            onTap {
                if (BoringtunLoader.supported) {
                    modal.openModal()
                    ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                } else showSnack(R.string.home_boringtun_not_loaded)
            }
        }
        Unit
    }

}
