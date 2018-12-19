package core

import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import kotlinx.coroutines.experimental.async
import retrofit2.Call
import retrofit2.Response
import tunnel.RestApi
import tunnel.RestModel

class GatewaysDashboardSectionVB(
        val ktx: AndroidKontext,
        val api: RestApi = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var items = emptyList<GatewayVB>()

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        if (items.isEmpty()) populateGateways()
        else view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

    private fun populateGateways() = async {
        api.getGateways().enqueue(object : retrofit2.Callback<RestModel.Gateways> {
            override fun onFailure(call: Call<RestModel.Gateways>?, t: Throwable?) {
                ktx.e("gateways api call error", t ?: "null")
            }

            override fun onResponse(call: Call<RestModel.Gateways>?, response: Response<RestModel.Gateways>?) {
                response?.run {
                    body()?.run {
                        gateways.forEach {
                            items += GatewayVB(ktx, it, onTap = slotMutex.openOneAtATime)
                        }
                        view?.set(items)
                    }
                }
            }
        })
    }
}
