package core.bits.menu.vpn

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import core.AndroidKontext
import core.BitVB
import core.BitView
import core.res
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import tunnel.showSnack

class CopyAccountVB(
        private val ktx: AndroidKontext
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_blocked.res())
        view.label(R.string.slot_account_show.res())
        view.state("******".res())
        ktx.on(BLOCKA_CONFIG, update)
    }

    override fun detach(view: BitView) {
        ktx.cancel(BLOCKA_CONFIG, update)
    }

    private val update = { cfg: BlockaConfig? ->
        if (cfg != null)
        view?.apply {
            onTap {
                // Show
                icon(R.drawable.ic_show.res())
                state(cfg.accountId.res())

                // Copy
                val clipboardManager = ktx.ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clipData = ClipData.newPlainText("account-id", cfg.accountId)
                clipboardManager.primaryClip = clipData
                showSnack(R.string.slot_account_action_copied)
            }
        }
        Unit
    }

}
