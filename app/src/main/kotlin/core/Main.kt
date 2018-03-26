package core

import buildtype.newBuildTypeModule
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import com.github.salomonbrys.kodein.lazy
import flavor.newFlavorModule
import gs.environment.newGscoreModule
import gs.main.GsApplication

/**
 * MainApplication puts together all modules.
 */
class MainApplication: GsApplication(), KodeinAware {

    override val kodein by Kodein.lazy {
        import(newGscoreModule(this@MainApplication))
        import(newAppModule(this@MainApplication), allowOverride = true)
        import(newFlavorModule(this@MainApplication), allowOverride = true)
        import(newBuildTypeModule(this@MainApplication), allowOverride = true)
    }
}
