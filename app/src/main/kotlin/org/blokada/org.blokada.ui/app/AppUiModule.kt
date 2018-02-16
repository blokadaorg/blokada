package org.blokada.ui.app

import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.instance
import org.blokada.app.Properties
import org.blokada.app.State
import org.blokada.framework.IJournal

fun newAppUiModule(): Kodein.Module {
    return Kodein.Module {
        onReady {
            val ui: UiState = instance()
            val s: State = instance()
            val j: IJournal = instance()

            // Show confirmation message to the user whenever notifications are enabled or disabled
            ui.notifications.doWhenChanged().then {
                if (ui.notifications()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_DISABLED)
                }
            }

            // Show confirmation message whenever keepAlive configuration is changed
            s.keepAlive.doWhenChanged().then {
                if (s.keepAlive()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_KEEPALIVE_DISABLED)
                }
            }

            // Report user property for notifications
            ui.notifications.doWhenSet().then {
                j.setUserProperty(Properties.NOTIFICATIONS, ui.notifications())
            }

            // Report user property for keepAlive
            s.keepAlive.doWhenSet().then {
                j.setUserProperty(Properties.KEEP_ALIVE, s.keepAlive())
            }

            // Persist dashes whenever done editing
            ui.editUi.doWhen { ui.editUi(false) }.then {
                ui.dashes %= ui.dashes()
            }
        }
    }
}

