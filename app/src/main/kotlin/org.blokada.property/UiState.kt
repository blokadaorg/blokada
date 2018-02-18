package org.blokada.property

import org.obsolete.IProperty
import org.blokada.property.Dash
import org.blokada.property.Info

abstract class UiState {

    abstract val seenWelcome: IProperty<Boolean>
    abstract val version: IProperty<Int>
    abstract val notifications: IProperty<Boolean>
    abstract val editUi: IProperty<Boolean>

    abstract val dashes: IProperty<List<Dash>>

    abstract val infoQueue: IProperty<List<Info>>

    abstract val lastSeenUpdateMillis: IProperty<Long>

    abstract val showSystemApps: IProperty<Boolean>
}
