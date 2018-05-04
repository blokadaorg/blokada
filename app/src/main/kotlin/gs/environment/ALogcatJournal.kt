package gs.environment

import android.util.Log

class ALogcatJournal(private val tag: String) : Journal {

    override fun event(vararg events: Any) {
        Log.i(tag, "event: ${events.joinToString(separator = ";")}")
    }

    override fun log(vararg errors: Any) {
        errors.forEach { when(it) {
            is Exception -> Log.e(tag, "------", it)
            else -> Log.e(tag, it.toString())
        }}
    }

    override fun setUserId(id: String) {
        Log.v(tag, "setUserId: $id")
    }

    override fun setUserProperty(key: String, value: Any) {
        Log.v(tag, "setUserProperty: $key=$value")
    }

}