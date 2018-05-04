package gs

import gs.environment.Journal

fun mockJournal(): Journal {
    return object : Journal {
        override fun event(vararg events: Any) {}
        override fun log(vararg errors: Any) {}
        override fun setUserId(id: String) {}
        override fun setUserProperty(key: String, value: Any) {}
    }
}
