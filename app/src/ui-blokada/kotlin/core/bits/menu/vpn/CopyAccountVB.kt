package core.bits.menu.vpn

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import blocka.CurrentAccount
import core.*
import org.blokada.R
import tunnel.showSnack

class CopyAccountVB(
        private val ktx: AndroidKontext
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_blocked.res())
        view.label(R.string.slot_account_show.res())
        view.state("******".res())
        on(CurrentAccount::class.java, this::update)
        update()
    }

    override fun detach(view: BitView) {
        cancel(CurrentAccount::class.java, this::update)
    }

    private fun update() {
        val cfg = get(CurrentAccount::class.java)
        view?.apply {
            state("******".res())
            onTap {
                if (cfg.id.isNotBlank()) {
                    // Show
                    icon(R.drawable.ic_show.res())
                    state(cfg.id.res())

                    // Copy
                    val clipboardManager = ktx.ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clipData = ClipData.newPlainText("account-id", cfg.id)
                    clipboardManager.primaryClip = clipData
                    showSnack(R.string.slot_account_action_copied)
                } else {
                    icon(R.drawable.ic_show.res())
                    state(R.string.slot_account_action_unavailable.res())
                }
            }
        }
        Unit
    }

}
