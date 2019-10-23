package core.bits.menu.vpn

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import blocka.CurrentAccount
import com.github.salomonbrys.kodein.instance
import com.github.thibseisel.kdenticon.Identicon
import com.github.thibseisel.kdenticon.android.AndroidBitmapRenderer
import core.*
import core.bits.openWebContent
import core.bits.pretty
import gs.property.I18n
import org.blokada.R
import tunnel.showSnack
import java.util.*

class AccountVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance()
) : core.AccountVB() {

    override fun attach(view: AccountView) {
        view.onTap {
        }
        view.onTap {
            val cfg = get(CurrentAccount::class.java)
            if (cfg.id.isNotBlank()) {
                // Show
                view.id(cfg.id.res())

                // Copy
                val clipboardManager = ktx.ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clipData = ClipData.newPlainText("account-id", cfg.id)
                clipboardManager.primaryClip = clipData
                showSnack(R.string.slot_account_action_copied)
            } else {
                view.id(R.string.slot_account_action_unavailable.res())
            }
        }
        on(CurrentAccount::class.java, this::update)
        update()
    }

    override fun detach(view: AccountView) {
        cancel(CurrentAccount::class.java, this::update)
    }

    private fun update() {
        val cfg = get(CurrentAccount::class.java)
        view?.apply {
            val isActive = cfg.activeUntil.after(Date())
            val accountLabel = if (isActive)
                i18n.getString(R.string.slot_account_label_active, cfg.activeUntil.pretty(ktx))
            else i18n.getString(R.string.slot_account_label_inactive)

            expired(accountLabel.res())

//            val stateLabel = if (isActive) R.string.slot_account_action_manage.res()
//            else R.string.slot_account_action_manage_inactive.res()
//           expirede(stateLabel)

            try {
                val icon = Identicon.fromValue(cfg.id, 300)
                val bitmap = Bitmap.createBitmap(300, 300, Bitmap.Config.ARGB_8888)
                val renderer = AndroidBitmapRenderer(bitmap)
                icon.draw(renderer, icon.getIconBounds())

                if (bitmap == null) throw Exception("no avatar bitmap")
                val drawable = BitmapDrawable(resources, bitmap)
                icon(Resource.of(drawable))
            } catch (ex: Exception) {
                icon(Resource.ofResId(R.drawable.ic_account_circle_black_24dp))
            }
        }
        Unit
    }
}

class AccountGoogleVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager
) : BitVB() {

    override fun attach(view: BitView) {
        view.icon(R.drawable.ic_account_circle_black_24dp.res())
        on(CurrentAccount::class.java, this::update)
        update()
    }

    override fun detach(view: BitView) {
        cancel(CurrentAccount::class.java, this::update)
    }

    private fun update() {
        val cfg = get(CurrentAccount::class.java)
        view?.apply {
            val isActive = cfg.activeUntil.after(Date())
            val accountLabel = if (isActive)
                i18n.getString(R.string.slot_account_label_active, cfg.activeUntil.pretty(ktx))
            else i18n.getString(R.string.slot_account_label_inactive)

            label(accountLabel.res())
        }
        Unit
    }
}
class SupportVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_help_outline.res())
        view.label(R.string.menu_vpn_support_button.res())
        view.onTap {
            modal.openModal()
            openWebContent(ktx.ctx, getSupportUrl())
        }
    }
}
