package org.blokada.app.android

import android.content.Context
import org.blokada.framework.IPersistence
import org.blokada.ui.app.android.DASH_ID_FIREBASE

/**
 * We need this persistence because of a reason described below. Note that keys used here has to be
 * in sync with ADashesPersistence.
 *
 * When dashes list is modified, it causes an immediate save to persistence. This would overwrite
 * the active state of FirebaseDash (ie it would always be inactive), hence we need to manually
 * read its persisted state before adding it to the dashes list.
 */
class AFirebaseDashPersistence(
        val ctx: Context
) : IPersistence<Boolean> {

    val p by lazy { ctx.getSharedPreferences("State", Context.MODE_PRIVATE) }

    override fun read(current: Boolean): Boolean {
        return p.getStringSet("dashes-active", setOf()).contains(DASH_ID_FIREBASE)
    }

    override fun write(source: Boolean) {
        // This persistence is not used for writing.
    }

}
