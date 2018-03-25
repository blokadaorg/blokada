package core

import android.content.Context
import gs.property.Persistence
import nl.komponents.kovenant.ui.promiseOnUi

class ADashesPersistence(
        val ctx: Context
) : Persistence<List<Dash>> {

    val p by lazy { ctx.getSharedPreferences("State2", Context.MODE_PRIVATE) }

    override fun read(current: List<Dash>): List<Dash> {
        val dashes = ArrayList(current)
        val updateDash = { id: String, active: Boolean ->
            promiseOnUi {
                val dash = dashes.firstOrNull { it.id == id }
                if (dash != null) {
                    dash.active = active
                }
            }
        }
        p.getStringSet("dashes-active", setOf()).forEach { id -> updateDash(id, true)}
        p.getStringSet("dashes-inactive", setOf()).forEach { id -> updateDash(id, false)}
        return dashes
    }

    override fun write(source: List<Dash>) {
        val e = p.edit()
        val active = source.filter(Dash::active).map(Dash::id).toSet()
        val inactive = source.filter { !it.active }.map(Dash::id).toSet()

        // Dashes which were active, but are not loaded yet (we preserve their state to read later)
        val ghosts = p.getStringSet("dashes-active", setOf())

        e.putStringSet("dashes-active", active.plus(ghosts).minus(inactive))
        e.putStringSet("dashes-inactive", inactive)
        e.apply()
    }

}
