package gs.environment

import android.content.Context
import gs.property.Persistence
import java.util.*

/**
 * Identity uniquely identifies the user.
 *
 * TODO: as version 2 support something like proquints
 * TODO: Use type alias on string once supported.
 */
class Identity internal constructor(private val version: Int, private val id: String) {
    override fun toString(): String {
        return when(version) {
            0 -> "00-" + id
            gs.environment.IDENTITY_UUID -> id
            else -> String.format("%02d-%s", version, id)
        }
    }
}

/**
 * generateIdentity provides a new pseudo-unique pseudo-random pseudo-identity.
 *
 * TODO: currently hardcoded.
 */
fun generateIdentity(version: Int): gs.environment.Identity {
    return when(version) {
        0 -> gs.environment.Identity(version, "anonymous")
        gs.environment.IDENTITY_UUID -> gs.environment.Identity(version, UUID.randomUUID().toString())
        else -> throw Exception("unknown version")
    }
}

/**
 * identityFrom creates Identity object out of its serialised representation.
 *
 * A new identity is provided in case it could not be de-serialised.
 */
fun identityFrom(id: String): gs.environment.Identity {
    return try {
        if (id.substring(2, 3) == "-") {
            val ver = id.substring(0, 2).toInt()
            val rest = id.substring(3)
            gs.environment.Identity(ver, rest)
        } else {
            gs.environment.Identity(IDENTITY_UUID, id)
        }
    } catch (e: Exception) {
        gs.environment.generateIdentity(IDENTITY_UUID)
    }
}

val IDENTITY_UUID = 1

class AIdentityPersistence(
        val ctx: Context
) : Persistence<Identity> {

    val p by lazy { ctx.getSharedPreferences("AState", Context.MODE_PRIVATE) }

    override fun read(current: Identity): Identity {
        return identityFrom(p.getString("id", ""))
    }

    override fun write(source: Identity) {
        val e = p.edit()
        e.putString("id", source.toString())
        e.apply()
    }

}
