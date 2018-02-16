package org.blokada.ui.app

/**
 * Dash defines the UI element to be displayed in the home screen as well as the UI that opens
 * up (optionally) once clicked.
 */
open class Dash (
    val id: String,
    icon: Any,
    var description: String? = null,
    active: Boolean = true,
    text: String? = null,
    val isSwitch: Boolean = false,
    checked: Boolean = false,
    val hasView: Boolean = false,
    emphasized: Boolean = false,
    val topBarColor: Int? = null,
    var menuDashes: Triple<Dash?, Dash?, Dash?> = Triple(null, null, null),
    var onClick: ((dashRef: Any) -> Boolean)? = null,
    var onDashOpen: () -> Unit = {},
    var onBack: () -> Unit = {},
    var onUpdate: MutableSet<() -> Unit> = mutableSetOf()
) {
    fun activate(active: Boolean): Dash {
        this.active = active
        return this
    }

    open var active = active
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open var emphasized = emphasized
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open var checked = checked
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    var icon = icon
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    var text = text
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open fun createView(parent: Any): Any? { return null }
}

enum class InfoType {
    CUSTOM, ERROR, PAUSED, PAUSED_TETHERING, PAUSED_OFFLINE, ACTIVE, ACTIVATING, DEACTIVATING,
    NOTIFICATIONS_ENABLED, NOTIFICATIONS_DISABLED,
    NOTIFICATIONS_KEEPALIVE_ENABLED, NOTIFICATIONS_KEEPALIVE_DISABLED
}

data class Info(val type: InfoType, val param: Any? = null)

