/* Copyright (C) 2017 Karsen Gauss <a@kar.gs>
 *
 * Derived from DNS66:
 * Copyright (C) 2016 Julian Andres Klode <jak@jak-linux.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * Contributions shall also be provided under any later versions of the
 * GPL.
 */
package adblocker

import android.content.Context
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import core.Dns
import core.Filters
import core.IEngineManager
import gs.environment.Journal
import gs.environment.Worker
import gs.environment.inject
import nl.komponents.kovenant.any
import nl.komponents.kovenant.task
import tunnel.ATunnelAgent
import tunnel.ATunnelBinder

class ALollipopEngineManager(
        private val ctx: Context,
        private val adBlocked: (String) -> Unit = {},
        private val error: (String) -> Unit = {},
        private val onRevoked: () -> Unit = {}
) : IEngineManager {

    private val s by lazy { ctx.inject().instance<Dns>() }
    private val f by lazy { ctx.inject().instance<Filters>() }
    private val waitKctx by lazy { ctx.inject().with("engineManagerWait").instance<Worker>() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private val events = ALollipopTunnelEvents(ctx, onRevoked)
    private var binder: ATunnelBinder? = null
    private var thread: TunnelThreadLollipopAndroid? = null
    private val agent by lazy { ATunnelAgent(ctx) }

    @Synchronized override fun start() {
        val binding = agent.bind(events)
        binding.success {
            binder = it
            binder!!.actions.turnOn()
            thread = TunnelThreadLollipopAndroid(it.actions, j, s, f, adBlocked, error)
        }
        val wait = task(waitKctx) {
            Thread.sleep(3000)
        }
        any(listOf(binding, wait)).get()
        if (!binding.isSuccess()) throw Exception("could not bind to lollipop agent")
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
