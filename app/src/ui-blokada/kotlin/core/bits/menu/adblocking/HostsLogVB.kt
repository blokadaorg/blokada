package core.bits.menu.adblocking

import android.app.Activity
import com.github.michaelbull.result.getOr
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.DomainBlockedVB
import core.bits.DomainForwarderVB
import core.bits.SearchBarVB
import core.bits.menu.MenuItemVB
import gs.environment.ComponentProvider
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.presentation.ViewBinder
import org.blokada.R
import tunnel.*
import tunnel.Persistence
import java.lang.IndexOutOfBoundsException

class HostsLogVB(
        val ktx: AndroidKontext,
        val activity: ComponentProvider<Activity> = ktx.di().instance(),
        override val name: Resource = R.string.panel_section_ads_log.res()
) : ListViewBinder(), NamedViewBinder {

    private val slotMutex = SlotMutex()

    private val items = mutableListOf<ViewBinder>()
    private var log: ExtendedRequestLog? = null
    private var searchString: String = ""

    var debuggingVar = emptySet<String>().toHashSet()
    private val requestUpdate = { update: RequestUpdate ->
                                    if (searchString.isEmpty() || update.newState.domain.contains(searchString.toLowerCase())) {
                                        val dash = requestToVB(update.newState)
                                        if (update.oldState == null) {
                                            debuggingVar.add(update.newState.domain)
                                            items.add(3, dash)
                                            view?.add(dash, 3)
                                        } else {
                                            if (!debuggingVar.contains(update.newState.domain))
                                                e("X_X")
                                            try {
                                                items[update.index + 3] = dash
                                                view?.set(items)
                                            } catch (e: IndexOutOfBoundsException){

                                            }
                                        }
                                    }
                                }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        if (log == null){
            log = ExtendedRequestLog()
            ktx.on(TunnelEvents.REQUEST_UPDATE, requestUpdate)
        }
        if(view.getItemCount() == 0) {
            items.clear()
            items.add(SearchBarVB(ktx, onSearch = { s ->
                searchString = s
                this.items.clear()
                view.set(emptyList())
                attach(view)
            }))
            items.add(ResetHostLogVB {
                ExtendedRequestLog.deleteAll()
                this.items.clear()
                view.set(emptyList())
                attach(view)
            })
            items.add(LabelVB(ktx, label = R.string.menu_ads_live_label.res()))
            if(log?.size == 0){
                log?.expandHistory()
            }
            log?.forEach {
                val dash = requestToVB(it)
                items.add(dash)
            }
        }

        view.set(items)
        view.onEndReached = loadMore
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        view.onEndReached = {}
        searchString = ""
        items.clear()
        view.set(emptyList())
        ktx.cancel(TunnelEvents.REQUEST_UPDATE, requestUpdate)
        log?.close()
        log = null
    }

    private val loadMore = {
        log?.expandHistory()
        Unit
    }


    private fun requestToVB(it: ExtendedRequest): SlotVB {
        return if (it.blocked)
            DomainBlockedVB(it.domain, it.time, ktx, alternative = true, onTap = slotMutex.openOneAtATime) else
            DomainForwarderVB(it.domain, it.time, ktx, alternative = true, onTap = slotMutex.openOneAtATime)
    }
}

fun createHostsLogMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_ads_log.res(),
            icon = R.drawable.ic_menu.res(),
            opens = HostsLogVB(ktx)
    )
}

class ResetHostLogVB(
        private val onReset: () -> Unit
) : BitVB() {

    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_reload.res())
        view.label(R.string.menu_ads_clear_log.res())
        view.onTap(onReset)
    }
}


