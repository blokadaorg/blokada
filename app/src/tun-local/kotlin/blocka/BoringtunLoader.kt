package blocka

internal class BoringtunLoader() {

    private var boringtunLoaded = false

    fun loadBoringtunOnce() {
        if (boringtunLoaded) return
        try {
            System.loadLibrary("boringtun")
        } catch (ex: Throwable) {
            throw BoringTunLoadException("failed loading boringtun library", ex)
        }
        boringtunLoaded = true
    }

}

class BoringTunLoadException(msg: String, cause: Throwable): Exception(msg, cause)
