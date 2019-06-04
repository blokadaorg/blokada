package core

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

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        if (items.size == 1) async { populateGateways() }
        else view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

    private fun populateGateways(retry: Int = 0) {
        api.getGateways().enqueue(object : retrofit2.Callback<RestModel.Gateways> {
            override fun onFailure(call: Call<RestModel.Gateways>?, t: Throwable?) {
                ktx.e("gateways api call error", t ?: "null")
                if (retry < MAX_RETRIES) populateGateways(retry + 1)
            }

            override fun onResponse(call: Call<RestModel.Gateways>?, response: Response<RestModel.Gateways>?) {
                response?.run {
                    when (code()) {
                        200 -> {
                            body()?.run {
                                gateways.forEach {
                                    items += GatewayVB(ktx, it, onTap = slotMutex.openOneAtATime)
                                }
                                view?.set(items)
                            }
                        }
                        else -> {
                            ktx.e("gateways api call response ${code()}")
                            if (retry < MAX_RETRIES) populateGateways(retry + 1)
                            Unit
                        }
                    }
                }
            }
        })
    }
}
