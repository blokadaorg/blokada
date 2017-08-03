package org.blokada.app

interface IFilterSource {
    fun fetch(): List<String>
    fun fromUserInput(vararg string: String): Boolean
    fun toUserInput(): String
    fun serialize(): String
    fun deserialize(string: String, version: Int): IFilterSource
    fun id(): String
}

interface IEngineManager {
    fun start()
    fun updateFilters()
    fun stop()
}

interface IPermissionsAsker {
    fun askForPermissions()
}

interface IWatchdog {
    fun start()
    fun stop()
    fun test(): Boolean
}