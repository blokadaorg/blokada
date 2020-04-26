package core.bits.menu.vpn

import android.content.Intent
import android.os.Handler
import blocka.BlockaRestApi
import blocka.BlockaRestModel
import blocka.MAX_RETRIES
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.SimpleMenuItemVB
import core.bits.menu.adblocking.SlotMutex
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.presentation.ViewBinder
import kotlinx.coroutines.experimental.async
import org.blokada.R
import retrofit2.Call
import retrofit2.Response
import ui.StaticUrlWebActivity

class GatewaysDashboardSectionVB(
    val ktx: AndroidKontext,
    val api: BlockaRestApi = ktx.di().instance(),
    override val name: Resource = R.string.menu_vpn_gateways.res()
) : ListViewBinder(), NamedViewBinder {

    private val slotMutex = SlotMutex()

    private var items = listOf<ViewBinder>(
        LabelVB(ktx, label = R.string.menu_vpn_gateways_label.res())
    )

    private val gatewaysRequest = Handler {
        async { populateGateways() }
        true
    }

    private fun update() {
        gatewaysRequest.removeMessages(0)
        gatewaysRequest.sendEmptyMessage(0)
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
        update()
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        gatewaysRequest.removeMessages(0)
    }

    private fun populateGateways(retry: Int = 0) {
        api.getGateways().enqueue(object : retrofit2.Callback<BlockaRestModel.Gateways> {
            override fun onFailure(call: Call<BlockaRestModel.Gateways>?, t: Throwable?) {
                ktx.e("gateways api call error", t ?: "null")
                if (retry < MAX_RETRIES) populateGateways(retry + 1)
                else gatewaysRequest.sendEmptyMessageDelayed(0, 5 * 1000)
            }

            override fun onResponse(
                call: Call<BlockaRestModel.Gateways>?,
                response: Response<BlockaRestModel.Gateways>?
            ) {
                response?.run {
                    when (code()) {
                        200 -> {
                            body()?.run {
                                val overloaded = gateways.filter { it.overloaded() }
                                val partner = gateways.filter { it.partner() }
                                val rest = gateways - partner - overloaded

                                val o = overloaded.map {
                                    GatewayVB(
                                        ktx,
                                        it,
                                        onTap = slotMutex.openOneAtATime
                                    )
                                }
                                val p = partner.map {
                                    GatewayVB(
                                        ktx,
                                        it,
                                        onTap = slotMutex.openOneAtATime
                                    )
                                } - o
                                val r = rest.map {
                                    GatewayVB(
                                        ktx,
                                        it,
                                        onTap = slotMutex.openOneAtATime
                                    )
                                }

                                items = listOf(
                                    LabelVB(ktx, label = R.string.menu_vpn_gateways_label.res())
                                ) + r

                                if (partner.isNotEmpty()) {
                                    items += listOf(
                                        LabelVB(
                                            ktx,
                                            label = R.string.slot_gateway_section_partner.res()
                                        )
                                    ) + p + listOf(
                                        LabelVB(
                                            ktx,
                                            label = R.string.slot_gateway_learn_more.res()
                                        ),
                                        createPartnerGatewaysMenuItem(ktx)
                                    )
                                }

                                if (overloaded.isNotEmpty()) {
                                    items += listOf(
                                        LabelVB(
                                            ktx,
                                            label = R.string.slot_gateway_section_overloaded.res()
                                        )
                                    ) + o
                                }

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

fun createPartnerGatewaysMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().vpn_partner
    return SimpleMenuItemVB(ktx,
        label = R.string.slot_gateway_info_partner.res(),
        icon = R.drawable.ic_info.res(),
        arrow = false,
        action = {
            modalManager.openModal()
            ktx.ctx.startActivity(Intent(ktx.ctx, StaticUrlWebActivity::class.java).apply {
                putExtra(WebViewActivity.EXTRA_URL, page().toExternalForm())
            })
        }
    )
}
