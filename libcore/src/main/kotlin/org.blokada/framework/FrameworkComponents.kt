package org.blokada.framework

typealias KContext = nl.komponents.kovenant.Context

interface IPersistence<T> {
    fun read(current: T): T
    fun write(source: T)
}

interface IEnvironment {
    fun now(): Long
}

interface IJournal {
    fun event(vararg events: Any)
    fun log(vararg errors: Any)
    fun setUserId(id: String)
    fun setUserProperty(key: String, value: Any)
}
