package gs.environment

interface Journal {
    fun event(vararg events: Any)
    fun log(vararg errors: Any)
    fun setUserId(id: String)
    fun setUserProperty(key: String, value: Any)
}

open class Events {
    open class EventGroup(val prefix: String, val suffix: String) {
        override fun toString(): String {
            return "%s_%s".format(prefix, suffix.toLowerCase().replace(" ", "_"))
        }
    }

    open class EventInt(val name: String, val value: Int) {
        override fun toString(): String {
            return name
        }
    }
}

open class Properties {
    companion object {
    }
}
