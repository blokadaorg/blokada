package buildtype

import android.content.Context
import android.util.Log
import com.crashlytics.android.Crashlytics
import com.google.firebase.analytics.FirebaseAnalytics
import gs.environment.Journal
import io.fabric.sdk.android.Fabric
import java.io.PrintWriter
import java.io.StringWriter

/**
 * Deps here need to be lazy to avoid dependency loop from Worker -> Journal
 */
class AFirebaseJournal(
        private val ctx: Context,
        private val firebase: () -> FirebaseAnalytics
) : Journal {

    init {
        Fabric.with(ctx)
    }

    private var userId: String? = null
    private val userProperties = mutableMapOf<String, String>()

    override fun setUserId(id: String) {
        userId = id
    }

    override fun setUserProperty(key: String, value: Any) {
        userProperties.put(key, value.toString())
    }

    override fun event(vararg events: Any) {
        events.forEach { event ->
            firebase().logEvent(event.toString(), null)
        }
    }

    override fun log(vararg errors: Any) {
        errors.forEach { error ->
            Crashlytics.log(Log.VERBOSE, "blokada", error.toString())
            if (error is Exception) {
                Crashlytics.logException(error)
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                Crashlytics.log(Log.VERBOSE, "blokada", sw.toString())
            }
        }
    }

}

