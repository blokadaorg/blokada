package core

import android.content.Context
import com.github.salomonbrys.kodein.*
import gs.environment.Environment
import gs.environment.Worker
import gs.property.*

abstract class Welcome {
    abstract val introSeen: IProperty<Boolean>
    abstract val guideSeen: IProperty<Boolean>
    abstract val patronShow: IProperty<Boolean>
    abstract val patronSeen: IProperty<Boolean>
    abstract val ctaSeenCounter: IProperty<Int>
    abstract val advanced: IProperty<Boolean>
    abstract val conflictingBuilds: IProperty<List<String>>
}

class WelcomeImpl (
        w: Worker,
        xx: Environment,
        val i18n: I18n = xx().instance()
) : Welcome() {
    override val introSeen = newPersistedProperty(w, BasicPersistence(xx, "intro_seen"), { false })
    override val guideSeen = newPersistedProperty(w, BasicPersistence(xx, "guide_seen"), { false })
    override val patronShow = newProperty(w, { false })
    override val patronSeen = newPersistedProperty(w, BasicPersistence(xx, "optional_seen"), { false })
    override val ctaSeenCounter = newPersistedProperty(w, BasicPersistence(xx, "cta_seen"), { 3 })
    override val advanced = newPersistedProperty(w, BasicPersistence(xx, "advanced"), { false })
    override val conflictingBuilds = newProperty(w, { listOf<String>() })

    init {
        i18n.locale.doWhenSet().then {
            patronShow %= true
        }

        conflictingBuilds %= listOf("org.blokada.origin.alarm", "org.blokada.alarm", "org.blokada", "org.blokada.dev")
    }
}

fun newWelcomeModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Welcome>() with singleton {
            WelcomeImpl(w = with("gscore").instance(2), xx = lazy)
        }
    }
}

