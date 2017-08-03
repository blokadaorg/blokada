package org.blokada.app.android

import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crash.FirebaseCrash
import org.blokada.app.Events
import org.blokada.framework.IJournal

/**
 * Deps here need to be lazy to avoid dependency loop from KContext -> IJournal
 */
class AFirebaseJournal(
        private val firebase: () -> FirebaseAnalytics,
        private val fState: FirebaseState
) : IJournal {

    private var userId: String? = null
    private val userProperties = mutableMapOf<String, String>()

    init {
        fState.enabled.doWhen { fState.enabled(true) }.then {
            if (userId != null) firebase().setUserId(userId)
            userProperties.forEach { k, v -> firebase().setUserProperty(k, v) }
        }
    }

    override fun setUserId(id: String) {
        if (fState.enabled()) firebase().setUserId(id)
        else userId = id
    }

    override fun setUserProperty(key: String, value: Any) {
        if (fState.enabled()) firebase().setUserProperty(key, value.toString())
        else userProperties.put(key, value.toString())
    }

    override fun event(vararg events: Any) {
        if (fState.enabled(false)) return
        events.forEach { event ->
            when(event) {
                is Events.EventInt -> {
                    val params =  Bundle()
                    params.putLong(FirebaseAnalytics.Param.QUANTITY, event.value.toLong())
                    firebase().logEvent(event.toString(), params)
                }
                is Events.AdBlocked -> {
                    val params =  Bundle()
                    params.putString(FirebaseAnalytics.Param.ITEM_NAME, event.host)
                    firebase().logEvent(event.name, params)
                }
                else -> firebase().logEvent(event.toString(), null)
            }
        }
    }

    override fun log(vararg errors: Any) {
        if (fState.enabled(false)) return
        errors.forEach { error ->
            when (error) {
                is Exception -> {
                    FirebaseCrash.report(error)
                }
                else -> {
                    FirebaseCrash.log(error.toString())
                }
            }
        }
    }

}

