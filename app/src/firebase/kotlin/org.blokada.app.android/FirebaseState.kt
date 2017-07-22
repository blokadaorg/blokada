package org.blokada.app.android

import org.blokada.framework.KContext
import org.blokada.framework.IProperty
import org.blokada.framework.newPersistedProperty
import android.content.Context

abstract class FirebaseState {
    abstract val enabled: IProperty<Boolean>
}

class AFirebaseState(
        private val ctx: Context,
        private val kctx: KContext
) : FirebaseState() {
    override val enabled = newPersistedProperty(kctx, APrefsPersistence(ctx, "firebaseEnabled"),
            zeroValue = { true }
    )
}