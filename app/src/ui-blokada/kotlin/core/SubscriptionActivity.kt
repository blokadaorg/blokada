package core

import blocka.CurrentAccount
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Worker
import gs.property.newProperty
import ui.AbstractWebActivity
import java.net.URL

var shouldRefreshAccount = false

fun getActivateUrl(): URL {
    val cfg = get(CurrentAccount::class.java)
    return URL("https://app.blokada.org/activate/${cfg.id}")
}

fun getSupportUrl(): URL {
    val cfg = get(CurrentAccount::class.java)
    return URL("https://app.blokada.org/support?account-id=${cfg.id}")
}

class SubscriptionActivity : AbstractWebActivity() {

    private val ktx = ktx("SubsbcriptionActivity")
    private val w: Worker by lazy { ktx.di().with("gscore").instance<Worker>() }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        targetUrl = newProperty(w, { getActivateUrl() })
        shouldRefreshAccount = true

        super.onCreate(savedInstanceState)
    }

}
