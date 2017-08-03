package org.blokada.framework

fun mockJournal(): IJournal {
    return object : IJournal {
        override fun event(vararg events: Any) {}
        override fun log(vararg errors: Any) {}
        override fun setUserId(id: String) {}
        override fun setUserProperty(key: String, value: Any) {}
    }
}
