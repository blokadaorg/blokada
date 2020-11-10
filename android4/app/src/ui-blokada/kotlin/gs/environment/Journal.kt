package gs.environment

interface Journal {
    fun event(vararg events: Any)
    fun log(vararg errors: Any)
    fun setUserId(id: String)
    fun setUserProperty(key: String, value: Any)
}

