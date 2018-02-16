package org.blokada.app.android

import android.app.Application
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import com.github.salomonbrys.kodein.lazy
import gs.environment.newGscoreModule
import org.blokada.environment.newAppModule

/**
 * MainApplication puts together all modules.
 */
class MainApplication: Application(), KodeinAware {
    override val kodein by Kodein.lazy {
        import(newGscoreModule(this@MainApplication))
        import(newAppModule(this@MainApplication))
    }
}
