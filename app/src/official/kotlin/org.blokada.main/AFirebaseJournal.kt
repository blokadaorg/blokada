package org.blokada.main

import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crash.FirebaseCrash
import gs.environment.Journal

/**
 * Deps here need to be lazy to avoid dependency loop from KContext -> Journal
 */
class AFirebaseJournal(
        private val firebase: () -> FirebaseAnalytics
) : Journal {

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

