package org.blokada.app.android.lollipop

import android.annotation.TargetApi
import android.content.Context
import android.net.VpnService
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import nl.komponents.kovenant.any
import org.blokada.app.IEngineManager
import org.blokada.app.State
import org.blokada.app.android.ATunnelAgent
import org.blokada.app.android.ATunnelBinder
import org.blokada.app.android.ITunnelEvents
import org.blokada.framework.android.hasIpV6Servers
import nl.komponents.kovenant.deferred
import nl.komponents.kovenant.task
import org.blokada.framework.KContext
import org.blokada.framework.android.di
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

@TargetApi(21)
class ALollipopEngineManager(
        private val ctx: Context,
        private val agent: ATunnelAgent,
        private val adBlocked: (String) -> Unit = {},
        private val error: (String) -> Unit = {},
        private val onRevoked: () -> Unit = {}
) : IEngineManager {

    private val s by lazy { ctx.di().instance<State>() }
    private val waitKctx by lazy { ctx.di().with("engineManagerWait").instance<KContext>() }
    private val events = ALollipopTunnelEvents(ctx, onRevoked)
    private var binder: ATunnelBinder? = null
    private var thread: TunnelThreadLollipopAndroid? = null

    @Synchronized override fun start() {
        val binding = agent.bind(events)
        binding.success {
            binder = it
            binder!!.actions.turnOn()
            thread = TunnelThreadLollipopAndroid(it.actions, s, adBlocked, error)
        }
        val wait = task(waitKctx) {
            Thread.sleep(3000)
        }
        any(listOf(binding, wait)).get()
        if (!binding.isSuccess()) throw Exception("could not bind to agent")
    }

    @Synchronized override fun updateFilters() {
        // Filters are fetched directly from the property
    }

    @Synchronized override fun stop() {
        thread?.stopThread()
        thread = null
        binder?.actions?.turnOff()
        agent.unbind()
        Thread.sleep(2000)
    }

}
