package ui.bits.menu.vpn

import android.os.Handler
import blocka.CurrentAccount
import blocka.MAX_RETRIES
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.adblocking.SlotMutex
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.presentation.ViewBinder
import kotlinx.coroutines.experimental.async
import org.blokada.R
import retrofit2.Call
import retrofit2.Response
import tunnel.RestApi
import tunnel.RestModel

class LeasesDashboardSectionVB(
        val ktx: AndroidKontext,
        val api: RestApi = ktx.di().instance(),
        override val name: Resource = R.string.menu_vpn_leases.res()
) : ListViewBinder(), NamedViewBinder {

    private val slotMutex = SlotMutex()

    private var items = listOf<ViewBinder>(
            LabelVB(ktx, label = R.string.slot_leases_info.res())
    )

    private val request = Handler {
        async { populate() }
        true
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
        request.sendEmptyMessage(0)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        request.removeMessages(0)
    }

    private fun populate(retry: Int = 0) {
        val currentAccount = get(CurrentAccount::class.java)
        api.getLeases(currentAccount.id).enqueue(object : retrofit2.Callback<RestModel.Leases> {
            override fun onFailure(call: Call<RestModel.Leases>?, t: Throwable?) {
                ktx.e("leases api call error", t ?: "null")
                if (retry < MAX_RETRIES) populate(retry + 1)
                else request.sendEmptyMessageDelayed(0, 5 * 1000)
            }

            override fun onResponse(call: Call<RestModel.Leases>?, response: Response<RestModel.Leases>?) {
                response?.run {
                    when (code()) {
                        200 -> {
                            body()?.run {
                                val g = leases.map {
                                    LeaseVB(ktx, it, onTap = slotMutex.openOneAtATime,
                                            onRemoved = {
                                                items = items - it
                                                view?.set(items)
                                                request.sendEmptyMessageDelayed(0, 2000)
                                            })
                                }
                                items = listOf(
                                    LabelVB(ktx, label = R.string.slot_leases_info.res())
                                ) + g
                                view?.set(items)
                            }
                        }
                        else -> {
                            ktx.e("leases api call response ${code()}")
                            if (retry < MAX_RETRIES) populate(retry + 1)
                            else request.sendEmptyMessageDelayed(0, 30 * 1000)
                            Unit
                        }
                    }
                }
            }
        })
    }
}
