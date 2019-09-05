package gs.property

import gs.environment.Environment
import gs.environment.Worker
import org.blokada.BuildConfig

abstract class Version {
    abstract val appName: IProperty<String>
    abstract val name: IProperty<String>
    abstract val previousCode: IProperty<Int>
    abstract val nameCore: IProperty<String>
    abstract val obsolete: IProperty<Boolean>
}

class VersionImpl(
        kctx: Worker,
        xx: Environment
) : Version() {

    override val appName = newProperty(kctx, { "gs" })
    override val name = newProperty(kctx, { "0.0" })
    override val previousCode = newPersistedProperty(kctx, BasicPersistence(xx, "previous_code"), { 0 })
    override val nameCore = newProperty(kctx, { BuildConfig.VERSION_NAME })
    override val obsolete = newProperty(kctx, { false })
}
