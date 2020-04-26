package blocka

import com.cloudflare.app.boringtun.BoringTunJNI
import core.e
import core.v

internal class BoringtunLoader {

    companion object {
        private var loaded = false

        var supported = true
            @Synchronized get() {
                return field
            }
            @Synchronized private set(value) {
                field = value
            }
    }

    fun loadBoringtunOnce() = when {
        loaded -> Unit
        !supported -> Unit
        else -> {
            try {
                System.loadLibrary("boringtun")
                loaded = true
            } catch (ex: Throwable) {
                supported = false
                e("failed loading boringtun", ex)
            }
            v(blokadaUserAgent())
        }
    }

    fun throwIfBoringtunUnavailable() = when {
        !supported -> throw BoringTunLoadException("boringtun not supported")
        !loaded -> throw BoringTunLoadException("boringtun not loaded")
        else -> Unit
    }

    fun generateKeypair() = {
        throwIfBoringtunUnavailable()
        try {
            val secret = BoringTunJNI.x25519_secret_key()
            val public = BoringTunJNI.x25519_public_key(secret)
            val secretString = BoringTunJNI.x25519_key_to_base64(secret)
            val publicString = BoringTunJNI.x25519_key_to_base64(public)
            secretString to publicString
        } catch (ex: Exception) {
            supported = false
            throw BoringTunLoadException("failed generating user keys", ex)
        }
    }()
}

class BoringTunLoadException internal constructor(msg: String, cause: Throwable? = null) :
    Exception(msg, cause)

