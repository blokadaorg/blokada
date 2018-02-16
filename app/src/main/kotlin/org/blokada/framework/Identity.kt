package org.blokada.framework

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
            IDENTITY_UUID -> id
            else -> String.format("%02d-%s", version, id)
        }
    }
}

/**
 * generateIdentity provides a new pseudo-unique pseudo-random pseudo-identity.
 *
 * TODO: currently hardcoded.
 */
fun generateIdentity(version: Int): Identity {
    return when(version) {
        0 -> Identity(version, "anonymous")
        IDENTITY_UUID -> Identity(version, UUID.randomUUID().toString())
        else -> throw Exception("unknown version")
    }
}

/**
 * identityFrom creates Identity object out of its serialised representation.
 *
 * A new identity is provided in case it could not be de-serialised.
 */
fun identityFrom(id: String): Identity {
    return try {
        if (id.substring(2, 3) == "-") {
            val ver = id.substring(0, 2).toInt()
            val rest = id.substring(3)
            Identity(ver, rest)
        } else {
            Identity(IDENTITY_UUID, id)
        }
    } catch (e: Exception) {
        generateIdentity(IDENTITY_UUID)
    }
}

val IDENTITY_UUID = 1
