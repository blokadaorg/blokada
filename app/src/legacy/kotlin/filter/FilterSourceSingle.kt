package filter

import tunnel.IFilterSource


val hostnameRegex = Regex("^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.)+[A-Za-z]{2,24}$")

class FilterSourceSingle(
        private var host: String = ""
) : IFilterSource {

    override fun size(): Int {
        return 1
    }

    override fun id(): String {
        return "single"
    }

    override fun fetch(): LinkedHashSet<String> {
        return if (hostnameRegex.containsMatchIn(host))
            LinkedHashSet<String>().apply { add(host) } else LinkedHashSet()
    }

    override fun fromUserInput(vararg string: String): Boolean {
        return if (hostnameRegex.containsMatchIn(string[0])) {
            host = string[0]
            true
        } else false
    }

    override fun toUserInput(): String {
        return host
    }

    override fun serialize(): String {
        return host
    }

    override fun deserialize(string: String, version: Int): FilterSourceSingle {
        host = string
        return this
    }

    override fun equals(other: Any?): Boolean {
        if (other !is FilterSourceSingle) return false
        return host.equals(other.host)
    }

    override fun hashCode(): Int {
        return host.hashCode()
    }
}
