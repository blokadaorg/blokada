package core

import android.os.Handler
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.presentation.ViewBinder
import kotlinx.coroutines.experimental.async
import retrofit2.Call
import retrofit2.Response
import tunnel.MAX_RETRIES
import tunnel.RestApi
import tunnel.RestModel

class GatewaysDashboardSectionVB(
        val ktx: AndroidKontext,
        val api: RestApi = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var items = listOf<ViewBinder>(
            BlockaVB(ktx, onTap = slotMutex.openOneAtATime)
    )

    private val gatewaysRequest = Handler {
        async { populateGateways() }
        true
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
        gatewaysRequest.sendEmptyMessage(0)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        gatewaysRequest.removeMessages(0)
    }

    private fun populateGateways(retry: Int = 0) {
        api.getGateways().enqueue(object : retrofit2.Callback<RestModel.Gateways> {
            override fun onFailure(call: Call<RestModel.Gateways>?, t: Throwable?) {
                ktx.e("gateways api call error", t ?: "null")
                if (retry < MAX_RETRIES) populateGateways(retry + 1)
                else gatewaysRequest.sendEmptyMessageDelayed(0, 5 * 1000)
            }

            override fun onResponse(call: Call<RestModel.Gateways>?, response: Response<RestModel.Gateways>?) {
                response?.run {
                    when (code()) {
                        200 -> {
                            body()?.run {
                                val g = gateways.map {
                                    GatewayVB(ktx, it, onTap = slotMutex.openOneAtATime)
                                }
                                items = listOf(items[0]) + g
                                view?.set(items)
                            }
                        }
                        else -> {
                            ktx.e("gateways api call response ${code()}")
                            if (retry < MAX_RETRIES) populateGateways(retry + 1)
                            else gatewaysRequest.sendEmptyMessageDelayed(0, 30 * 1000)
                            Unit
                        }
                    }
                }
            }
        })
    }
}
