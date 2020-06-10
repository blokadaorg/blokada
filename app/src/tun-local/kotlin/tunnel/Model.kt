package tunnel

import core.Time
import core.Url
import java.net.InetAddress
import java.util.*

typealias MemoryLimit = Int
typealias FilterId = String
typealias Ruleset = LinkedHashSet<String>

data class Filter(
        val id: FilterId,
        val source: FilterSourceDescriptor,
        val whitelist: Boolean = false,
        val active: Boolean = false,
        val hidden: Boolean = false,
        val priority: Int = 0,
        val lastFetch: Time = 0,
        val credit: String? = null,
        val customName: String? = null,
        val customComment: String? = null
) {
    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (other !is Filter) return false
        return id == other.id
    }

    override fun toString(): String {
        return id
    }
}

data class FilterStore(
        val cache: Set<Filter> = emptySet(),
        val lastFetch: Time = 0,
        val url: Url = ""
)

fun Set<Filter>.prioritised(): Set<Filter> {
    return toList().sortedBy { it.priority }.mapIndexed { i, f -> f.copy(priority = i) }.toSet()
}

fun List<Filter>.prioritised(): List<Filter> {
    return sortedBy { it.priority }.mapIndexed { i, f -> f.copy(priority = i) }
}

class Memory {
    companion object {
        val linesAvailable = {
            val r = Runtime.getRuntime()
            val free = r.maxMemory() - (r.totalMemory() - r.freeMemory())
            (free / (21 * 2 * 3)).toInt() // (avg chars per host name) * (unicode char size) * (correction)
        }
    }
}

// TODO: better model here
interface IFilterSource {
    fun size(): Int
    fun fetch(): LinkedHashSet<String>
    fun fromUserInput(vararg string: String): Boolean
    fun toUserInput(): String
    fun serialize(): String
    fun deserialize(string: String, version: Int): IFilterSource
    fun id(): String
}

class FilterSourceDescriptor(
        val id: String,
        val source: String
) {
    override fun toString(): String {
        return "$id:$source"
    }
}

val EXPIRATION_OFFSET = 60 * 1000

data class BlockaConfig(
        val adblocking: Boolean = true,
        val blockaVpn: Boolean = false,
        val accountId: String = "",
        val restoredAccountId: String = "",
        val activeUntil: Date = Date(0),
        val leaseActiveUntil: Date = Date(0),
        val privateKey: String = "",
        val publicKey: String = "",
        val gatewayId: String = "",
        val gatewayIp: String = "",
        val gatewayPort: Int = 0,
        val gatewayNiceName: String = "",
        val vip4: String = "",
        val vip6: String = "",
        val lastDaily: Long = 0L
) {

    fun getAccountExpiration() = Date(activeUntil.time - EXPIRATION_OFFSET)
    fun getLeaseExpiration() = Date(leaseActiveUntil.time - EXPIRATION_OFFSET)

    fun hasGateway(): Boolean {
        return gatewayId.isNotBlank() && gatewayIp.isNotBlank() && gatewayPort != 0
    }

    override fun toString(): String {
        return "BlockaConfig(acc=$accountId, restAcc=$restoredAccountId, adblocking=$adblocking, blockaVpn=$blockaVpn, activeUntil=$activeUntil, leaseActiveUntil=$leaseActiveUntil, publicKey='$publicKey', gatewayId='$gatewayId', gatewayIp='$gatewayIp', gatewayPort=$gatewayPort, vip4='$vip4', vip6='$vip6')"
    }
}

interface Request{
        val domain: String
        val blocked: Boolean
        val time: Date
}

data class SimpleRequest(
        override val domain: String,
        override val blocked: Boolean = false,
        override val time: Date = Date()
) : Request {
    override fun equals(other: Any?): Boolean {
        return if (other !is Request) false
        else domain == other.domain
    }

    override fun hashCode(): Int {
        return domain.hashCode()
    }
}

enum class RequestState {
    BLOCKED_NORMAL,      // blocked by blacklist
    BLOCKED_CNAME,       // blocked by cname-check
    BLOCKED_ANSWER,      // blocked by DNS-server
    ALLOWED_APP_UNKNOWN, // allowed app unknown
    ALLOWED_APP_KNOWN    // allowed app known ( future use in firewall )
}


data class ExtendedRequest(
        override val domain: String,
        override val time: Date = Date(),
        var requestId: Int? = null,
        var state: RequestState = RequestState.ALLOWED_APP_UNKNOWN,
        var ip: InetAddress? = null, // for future use in firewall
        var appId: String? = null    // for future use in firewall
) : Request {
    override val blocked: Boolean
        get() = (state != RequestState.ALLOWED_APP_UNKNOWN && state != RequestState.ALLOWED_APP_KNOWN)

    constructor(r: Request) : this(r.domain, r.time, state = if(r.blocked) { RequestState.BLOCKED_NORMAL } else { RequestState.ALLOWED_APP_UNKNOWN })
    constructor(domain: String, blocked: Boolean) : this( domain, state = if(blocked) { RequestState.BLOCKED_NORMAL } else { RequestState.ALLOWED_APP_UNKNOWN })


    override fun equals(other: Any?): Boolean {
        if (other is Request) {
            if ((requestId != null) && other is ExtendedRequest && (other.requestId != null) ) {
                return requestId == other.requestId
            }
            return domain == other.domain
        }
        return false
    }
}

data class RequestUpdate(
        val oldState: ExtendedRequest?,
        val newState: ExtendedRequest,
        val index: Int
)
