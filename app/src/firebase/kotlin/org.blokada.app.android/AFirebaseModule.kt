package org.blokada.app.android

import com.github.salomonbrys.kodein.*
import com.google.firebase.analytics.FirebaseAnalytics
import org.blokada.R
import org.blokada.app.IHostlineProcessor
import org.blokada.app.hostnameRegex
import gs.environment.Journal
import org.blokada.framework.newConcurrentKContext
import org.blokada.ui.app.UiState
import org.blokada.ui.app.android.FirebaseDashOn
import org.blokada.app.State
import org.blokada.ui.app.Info
import org.blokada.ui.app.InfoType

fun newFirebaseModule(): Kodein.Module {
    return Kodein.Module {
        bind<FirebaseState>() with singleton {
            AFirebaseState(ctx = instance(), kctx = newConcurrentKContext(null, "firebasestate", 1))
        }
        bind<FirebaseAnalytics>() with singleton {
            FirebaseAnalytics.getInstance(instance())
        }
        bind<Journal>(overrides = true) with singleton {
            AFirebaseJournal(firebase = provider(), fState = instance())
        }
        bind<IHostlineProcessor>(overrides = true) with singleton {
            object : IHostlineProcessor {
                override fun process(line: String): String? {
                    var l = line
                    if (l.startsWith("#")) return null
                    if (l.startsWith("<")) return null
                    if (l.endsWith("firebase.com")) return null
                    l = l.replaceFirst("0.0.0.0 ", "")
                    l = l.replaceFirst("127.0.0.1 ", "")
                    l = l.replaceFirst("127.0.0.1	", "")
                    l = l.trim()
                    if (l.isEmpty()) return null
                    if (!hostnameRegex.containsMatchIn(l)) return null
                    return l
                }
            }
        }
        onReady {
            // Add Firebase switch dash to the home screen
            val ui: UiState = instance()
            val fState: FirebaseState = instance()

            var added = false
            ui.dashes.doWhenSet().then {
                if (!added) {
                    added = true
                    ui.dashes %= ui.dashes().plus(
                            FirebaseDashOn(ctx = instance(), fState = instance()).activate(
                                    AFirebaseDashPersistence(ctx = instance()).read(false)
                            )
                    )
                    ui.dashes.refresh(force = true) // To read persistence again for the just added dash
                }
            }

            // Show confirmation message to the user whenever reporting is enabled or disabled
            fState.enabled.doWhenChanged().then {
                if (fState.enabled()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, R.string.main_tracking_enabled)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, R.string.main_tracking_disabled)
                }
            }
        }
    }
}

