package org.blokada.app.android

import org.blokada.app.EngineEvents
import org.blokada.app.IEngineManager
import org.blokada.app.State

/**
 * Dynamically changes the engine based on user configuration.
 */
class AEngineManagerProvider(
        private val s: State,
        private val adBlocked: (String) -> Unit = {},
        private val error: (String) -> Unit = {},
        private val onRevoked: () -> Unit = {}
) : IEngineManager {

    private val instances by lazy { s.tunnelEngines().map { it.createIEngineManager(
            EngineEvents(
                    adBlocked = adBlocked,
                    error = error,
                    onRevoked = onRevoked
            )
    )}}

    private var currentEngine : IEngineManager? = null

    @Synchronized override fun start() {
        val e = s.tunnelEngines().first { it.id == s.tunnelActiveEngine() }
        currentEngine = instances[s.tunnelEngines().indexOf(e)]
        currentEngine!!.start()
    }

    @Synchronized override fun stop() {
        currentEngine!!.stop()
    }

    @Synchronized override fun updateFilters() {
        currentEngine?.updateFilters()
    }

}