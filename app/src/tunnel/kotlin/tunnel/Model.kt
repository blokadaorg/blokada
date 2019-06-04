package tunnel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.cloudflare.app.boringtun.BoringTunJNI
import com.github.salomonbrys.kodein.instance
import core.*
import kotlinx.coroutines.experimental.async
import retrofit2.Call
import retrofit2.Response
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
            (free / (18 * 2 * 6)).toInt() // (avg chars per host name) * (char size) * (correction)
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

// TODO: rename to something else
data class TunnelConfig(
        val wifiOnly: Boolean = true,
        val firstLoad: Boolean = true,
        val powersave: Boolean = false,
        val dnsFallback: Boolean = true,
        val report: Boolean = false,
        val cacheTTL: Long = 86400
)

val TUNNEL_CONFIG = "TUNNEL_CONFIG".newEventOf<TunnelConfig>()

fun registerTunnelConfigEvent(ktx: Kontext) {
    val config = Persistence.config.load(ktx)
    ktx.emit(TUNNEL_CONFIG, config)
    ktx.on(TUNNEL_CONFIG, { Persistence.config.save(it) })
}

// TODO: can be null?
data class BlockaConfig(
        val adblocking: Boolean = true,
        val blockaVpn: Boolean = false,
        val accountId: String = "",
        val activeUntil: Date = Date(0),
        val leaseActiveUntil: Date = Date(0),
        val privateKey: String = "",
        val publicKey: String = "",
        val gatewayId: String = "",
        val gatewayIp: String = "",
        val gatewayPort: Int = 0,
        val gatewayNiceName: String = "",
        val vip4: String = "",
        val vip6: String = ""
)

val BLOCKA_CONFIG = "BLOCKA_CONFIG".newEventOf<BlockaConfig>()

fun registerBlockaConfigEvent(ktx: AndroidKontext) {
    val config = Persistence.blocka.load(ktx)

    ktx.v("loading boringtun and generating keys")
    System.loadLibrary("boringtun")

    // First time set values
    if (config.accountId.isEmpty()) {
        newAccount(ktx, config)
    } else {
        checkAccountInfo(ktx, config)
    }

    ktx.emit(BLOCKA_CONFIG, config)
    ktx.on(BLOCKA_CONFIG, { Persistence.blocka.save(it) })
}

val MAX_RETRIES = 3
fun newAccount(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.newAccount().enqueue(object: retrofit2.Callback<RestModel.Account> {
        override fun onFailure(call: Call<RestModel.Account>?, t: Throwable?) {
            ktx.e("new account api call error", t ?: "null")
            if (retry < MAX_RETRIES) newAccount(ktx, config, retry + 1)
        }

        override fun onResponse(call: Call<RestModel.Account>?, response: Response<RestModel.Account>?) {
            response?.run { body()?.run {
                val secret = BoringTunJNI.x25519_secret_key()
                val public = BoringTunJNI.x25519_public_key(secret)
                val newCfg = config.copy(
                        accountId = account.accountId,
                        privateKey = BoringTunJNI.x25519_key_to_base64(secret),
                        publicKey = BoringTunJNI.x25519_key_to_base64(public)
                )
                ktx.emit(BLOCKA_CONFIG, newCfg)
                ktx.v("new user. account id: ${newCfg.accountId}, public key: ${newCfg.publicKey}")
            } }
        }
    })
}

fun checkAccountInfo(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.getAccountInfo(config.accountId).enqueue(object: retrofit2.Callback<RestModel.Account> {
        override fun onFailure(call: Call<RestModel.Account>?, t: Throwable?) {
            ktx.e("new account api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkAccountInfo(ktx, config, retry + 1)
        }

        override fun onResponse(call: Call<RestModel.Account>?, response: Response<RestModel.Account>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val newCfg = config.copy(
                                    activeUntil = account.activeUntil
                            )
                            ktx.emit(BLOCKA_CONFIG, newCfg)
                            ktx.v("current account active until: ${newCfg.activeUntil}")
                            checkLease(ktx, newCfg)
                        }
                    }
                    else -> {
                        ktx.e("new account api call response ${code()}")
                        if (retry < MAX_RETRIES) checkAccountInfo(ktx, config, retry + 1)
                        Unit
                    }
                }
            }
        }
    })
}

fun checkGateways(ktx: AndroidKontext, config: BlockaConfig, gatewayId: String?, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.getGateways().enqueue(object: retrofit2.Callback<RestModel.Gateways> {
        override fun onFailure(call: Call<RestModel.Gateways>?, t: Throwable?) {
            ktx.e("gateways api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkGateways(ktx, config, gatewayId, retry + 1)
        }

        override fun onResponse(call: Call<RestModel.Gateways>?, response: Response<RestModel.Gateways>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val gateway = gateways.firstOrNull { it.publicKey == gatewayId }
                            if (gateway != null) {
                                val newCfg = config.copy(
                                        gatewayId = gateway.publicKey,
                                        gatewayIp = gateway.ipv4,
                                        gatewayPort = gateway.port,
                                        gatewayNiceName = gateway.niceName()
                                )
                                ktx.v("found gateway, chosen: ${newCfg.gatewayId}")
                                ktx.emit(BLOCKA_CONFIG, newCfg)
                            } else {
                                ktx.v("found no matching gateway")
                                newLease(ktx, config, gateways.first())
                            }
                        }
                    }
                    else -> {
                        ktx.e("gateways api call response ${code()}")
                        if (retry < MAX_RETRIES) checkGateways(ktx, config, gatewayId, retry + 1)
                        Unit
                    }
                }
            }
        }
    })
}

fun checkLease(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.getLeases(config.accountId).enqueue(object: retrofit2.Callback<RestModel.Leases> {
        override fun onFailure(call: Call<RestModel.Leases>?, t: Throwable?) {
            ktx.e("leases api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkLease(ktx, config, retry + 1)
        }

        override fun onResponse(call: Call<RestModel.Leases>?, response: Response<RestModel.Leases>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            // User might have a lease for old private key (if restoring account)
                            val obsoleteLeases = leases.filter { it.publicKey != config.publicKey }
                            obsoleteLeases.forEach { deleteLease(ktx, config, it.publicKey, it.gatewayId) }

                            val lease = leases.firstOrNull { it.publicKey == config.publicKey }
                            if (lease != null && lease.expires.after(Date(Date().time + 3600 * 1000))) {
                                val newCfg = config.copy(
                                        vip4 = lease.vip4,
                                        vip6 = lease.vip6
                                )
                                ktx.v("found active lease until: ${lease.expires}")
                                ktx.emit(BLOCKA_CONFIG, newCfg)
                                checkGateways(ktx, config, lease.gatewayId)
                                scheduleLeaseRenew(ktx, config)
                            } else {
                                ktx.v("no active lease")
                                checkGateways(ktx, config, null)
                            }
                        }
                    }
                    else -> {
                        ktx.e("leases api call response ${code()}")
                        if (retry < MAX_RETRIES) checkLease(ktx, config, retry + 1)
                        Unit
                    }
                }
            }
        }
    })
}

fun deleteLease(ktx: AndroidKontext, config: BlockaConfig, publicKey: String, gatewayId: String, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()

    // TODO: rewrite it to sync version, or use callback on finish
    api.deleteLease(RestModel.LeaseRequest(config.accountId, publicKey, gatewayId)).enqueue(object: retrofit2.Callback<Void> {

        override fun onFailure(call: Call<Void>?, t: Throwable?) {
            ktx.e("delete lease api call error", t ?: "null")
            if (retry < MAX_RETRIES) deleteLease(ktx, config, publicKey, gatewayId, retry + 1)
        }

        override fun onResponse(call: Call<Void>?, response: Response<Void>?) {
            ktx.e("obsolete lease deleted", publicKey, gatewayId)
        }

    })
}

fun redoLease(ktx: AndroidKontext, config: BlockaConfig, gateway: RestModel.GatewayInfo, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()

    api.deleteLease(RestModel.LeaseRequest(config.accountId, config.publicKey, gateway.publicKey)).enqueue(object: retrofit2.Callback<Void> {

        override fun onFailure(call: Call<Void>?, t: Throwable?) {
            ktx.e("delete lease api call error", t ?: "null")
            if (retry < MAX_RETRIES) redoLease(ktx, config, gateway, retry + 1)
            else newLease(ktx, config, gateway)
        }

        override fun onResponse(call: Call<Void>?, response: Response<Void>?) {
            newLease(ktx, config, gateway)
        }

    })
}

fun newLease(ktx: AndroidKontext, config: BlockaConfig, gateway: RestModel.GatewayInfo, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()

    api.newLease(RestModel.LeaseRequest(config.accountId, config.publicKey, gateway.publicKey)).enqueue(object: retrofit2.Callback<RestModel.Lease> {
        override fun onFailure(call: Call<RestModel.Lease>?, t: Throwable?) {
            ktx.e("new lease api call error", t ?: "null")
            if (retry < MAX_RETRIES) newLease(ktx, config, gateway, retry + 1)
        }

        override fun onResponse(call: Call<RestModel.Lease>?, response: Response<RestModel.Lease>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val newCfg = config.copy(
                                    gatewayId = gateway.publicKey,
                                    gatewayIp = gateway.ipv4,
                                    gatewayPort = gateway.port,
                                    gatewayNiceName = gateway.niceName(),
                                    vip4 = lease.vip4,
                                    vip6 = lease.vip6,
                                    leaseActiveUntil = lease.expires,
                                    blockaVpn = true
                            )
                            ktx.v("new active lease, until: ${lease.expires}")
                            ktx.emit(BLOCKA_CONFIG, newCfg)
                            scheduleLeaseRenew(ktx, config)
                        }
                    }
                    else -> {
                        ktx.e("new lease api call response ${code()}")
                        if (retry < MAX_RETRIES) newLease(ktx, config, gateway, retry + 1)
                        Unit
                    }
                }
            }
        }
    })
}

fun scheduleLeaseRenew(ktx: AndroidKontext, config: BlockaConfig) {
    val alarm: AlarmManager = ktx.ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    val operation = Intent(ktx.ctx, RenewLicenseReceiver::class.java).let { intent ->
        PendingIntent.getBroadcast(ktx.ctx, 0, intent, 0)
    }

    val time = config.leaseActiveUntil.time - 3600 * 1000 // An hour before lease ends
    alarm.set(AlarmManager.RTC, time, operation)
    ktx.v("scheduled lease for an hour before ${config.leaseActiveUntil}")
}

class RenewLicenseReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        async {
            val ktx = ctx.ktx("renew-lease")
            ktx.v("renew lease task executing")
            val config = ktx.getMostRecent(BLOCKA_CONFIG)!!
            checkLease(ktx, config)
        }
    }
}

data class Request(
        val domain: String,
        val blocked: Boolean = false,
        val time: Date = Date()
) {
    override fun equals(other: Any?): Boolean {
        return domain.equals(other)
    }

    override fun hashCode(): Int {
        return domain.hashCode()
    }
}
