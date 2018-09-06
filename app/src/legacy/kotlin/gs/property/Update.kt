package gs.property

import gs.environment.Environment
import gs.environment.Worker

/**
 *
 */
abstract class Update {
    abstract val updating: IProperty<Boolean>
}

class UpdateImpl(
        private val kctx: Worker,
        private val xx: Environment
) : Update() {
    override val updating = newProperty(kctx, { false })
}
