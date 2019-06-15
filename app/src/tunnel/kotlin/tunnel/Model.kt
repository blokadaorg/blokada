package tunnel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast
import com.cloudflare.app.boringtun.BoringTunJNI
import com.github.salomonbrys.kodein.instance
import core.*
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import org.blokada.R
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
) {

    fun hasGateway(): Boolean {
        return gatewayId.isNotBlank() && gatewayIp.isNotBlank() && gatewayPort != 0
    }

    override fun toString(): String {
        return "BlockaConfig(adblocking=$adblocking, blockaVpn=$blockaVpn, accountId='$accountId', activeUntil=$activeUntil, leaseActiveUntil=$leaseActiveUntil, publicKey='$publicKey', gatewayId='$gatewayId', gatewayIp='$gatewayIp', gatewayPort=$gatewayPort, vip4='$vip4', vip6='$vip6')"
    }
}

val BLOCKA_CONFIG = "BLOCKA_CONFIG".newEventOf<BlockaConfig>()

fun registerBlockaConfigEvent(ktx: AndroidKontext) {
    val config = Persistence.blocka.load(ktx)

    ktx.v("loading boringtun")
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
private fun newAccount(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
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

fun checkAccountInfo(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0, showError: Boolean = false) {
    val api: RestApi = ktx.di().instance()
    api.getAccountInfo(config.accountId).enqueue(object: retrofit2.Callback<RestModel.Account> {
        override fun onFailure(call: Call<RestModel.Account>?, t: Throwable?) {
            ktx.e("check account api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkAccountInfo(ktx, config, retry + 1, showError)
            else if (showError) Toast.makeText(ktx.ctx, R.string.slot_account_name_api_error, Toast.LENGTH_LONG).show()
        }

        override fun onResponse(call: Call<RestModel.Account>?, response: Response<RestModel.Account>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val newCfg = config.copy(
                                    activeUntil = account.activeUntil
                            )
                            if (account.activeUntil.after(Date())) {
                                ktx.v("current account active until: ${newCfg.activeUntil}")
                                checkGateways(ktx, newCfg)
                            } else {
                                ktx.v("current account inactive")
                                if (newCfg.blockaVpn) {
                                    Toast.makeText(ktx.ctx, R.string.account_inactive, Toast.LENGTH_LONG).show()
                                    ktx.emit(BLOCKA_CONFIG, newCfg.copy(blockaVpn = false))
                                }
                            }
                        }
                    }
                    else -> {
                        ktx.e("check account api call response ${code()}")
                        if (retry < MAX_RETRIES) checkAccountInfo(ktx, config, retry + 1, showError)
                        else if (showError) Toast.makeText(ktx.ctx, R.string.slot_account_name_api_error, Toast.LENGTH_LONG).show()
                        Unit
                    }
                }
            }
        }
    })
}

fun clearConnectedGateway(ktx: AndroidKontext, config: BlockaConfig, showError: Boolean = true) {
    if (config.blockaVpn && showError) Toast.makeText(ktx.ctx, R.string.lease_cant_connect, Toast.LENGTH_LONG).show()
    ktx.emit(BLOCKA_CONFIG, config.copy(
            blockaVpn = false,
            gatewayId = "",
            gatewayIp = "",
            gatewayPort = 0,
            gatewayNiceName = ""
    ))
}

fun checkGateways(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.getGateways().enqueue(object: retrofit2.Callback<RestModel.Gateways> {
        override fun onFailure(call: Call<RestModel.Gateways>?, t: Throwable?) {
            ktx.e("gateways api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkGateways(ktx, config, retry + 1)
            else clearConnectedGateway(ktx, config)
        }

        override fun onResponse(call: Call<RestModel.Gateways>?, response: Response<RestModel.Gateways>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val gateway = gateways.firstOrNull { it.publicKey == config.gatewayId }
                            if (gateway != null) {
                                val newCfg = config.copy(
                                        gatewayId = gateway.publicKey,
                                        gatewayIp = gateway.ipv4,
                                        gatewayPort = gateway.port,
                                        gatewayNiceName = gateway.niceName()
                                )
                                ktx.v("found gateway, chosen: ${newCfg.gatewayId}")
//                                if (newCfg.leaseActiveUntil.before(Date())) {
//                                    ktx.v("old lease, refresh")
//                                    newLease(ktx, newCfg)
//                                } else {
                                    checkLease(ktx, newCfg)
//                                }
                                Unit
                            } else {
                                ktx.v("found no matching gateway")
                                clearConnectedGateway(ktx, config)
                            }
                        }
                    }
                    else -> {
                        ktx.e("gateways api call response ${code()}")
                        if (retry < MAX_RETRIES) checkGateways(ktx, config, retry + 1)
                        else clearConnectedGateway(ktx, config)
                        Unit
                    }
                }
            }
        }
    })
}

fun checkLeaseIfNeeded(ktx: AndroidKontext) {
    async {
        ktx.getMostRecent(BLOCKA_CONFIG)?.run {
            if (leaseActiveUntil.before(Date())) checkLease(ktx, this)
        }
    }
}

private fun checkLease(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()
    api.getLeases(config.accountId).enqueue(object: retrofit2.Callback<RestModel.Leases> {
        override fun onFailure(call: Call<RestModel.Leases>?, t: Throwable?) {
            ktx.e("leases api call error", t ?: "null")
            if (retry < MAX_RETRIES) checkLease(ktx, config, retry + 1)
            else clearConnectedGateway(ktx, config)
        }

        override fun onResponse(call: Call<RestModel.Leases>?, response: Response<RestModel.Leases>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            // User might have a lease for old private key (if restoring account)
                            val obsoleteLeases = leases.filter { it.publicKey != config.publicKey }
                            obsoleteLeases.forEach { deleteLease(ktx, config.copy(
                                    publicKey = it.publicKey,
                                    gatewayId = it.gatewayId
                            )) }

                            val lease = leases.firstOrNull {
                                it.publicKey == config.publicKey && it.gatewayId == config.gatewayId
                            }
                            if (lease != null && lease.expires.after(Date(Date().time + 1800 * 1000))) {
                                val newCfg = config.copy(
                                        vip4 = lease.vip4,
                                        vip6 = lease.vip6,
                                        leaseActiveUntil = lease.expires,
                                        blockaVpn = true
                                )
                                ktx.v("found active lease until: ${lease.expires}")
                                ktx.emit(BLOCKA_CONFIG, newCfg)
                                scheduleRecheck(ktx, newCfg)
                            } else {
                                ktx.v("no active lease")
                                newLease(ktx, config)
                            }
                        }
                    }
                    else -> {
                        ktx.e("leases api call response ${code()}")
                        if (retry < MAX_RETRIES) checkLease(ktx, config, retry + 1)
                        else clearConnectedGateway(ktx, config)
                        Unit
                    }
                }
            }
        }
    })
}

private fun deleteLease(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()

    // TODO: rewrite it to sync version, or use callback on finish
    api.deleteLease(RestModel.LeaseRequest(config.accountId, config.publicKey, config.gatewayId)).enqueue(object: retrofit2.Callback<Void> {

        override fun onFailure(call: Call<Void>?, t: Throwable?) {
            ktx.e("delete lease api call error", t ?: "null")
            if (retry < MAX_RETRIES) deleteLease(ktx, config, retry + 1)
        }

        override fun onResponse(call: Call<Void>?, response: Response<Void>?) {
            ktx.e("obsolete lease deleted")
        }

    })
}

private fun newLease(ktx: AndroidKontext, config: BlockaConfig, retry: Int = 0) {
    val api: RestApi = ktx.di().instance()

    api.newLease(RestModel.LeaseRequest(config.accountId, config.publicKey, config.gatewayId)).enqueue(object: retrofit2.Callback<RestModel.Lease> {
        override fun onFailure(call: Call<RestModel.Lease>?, t: Throwable?) {
            ktx.e("new lease api call error", t ?: "null")
            if (retry < MAX_RETRIES) newLease(ktx, config, retry + 1)
            else clearConnectedGateway(ktx, config)
        }

        override fun onResponse(call: Call<RestModel.Lease>?, response: Response<RestModel.Lease>?) {
            response?.run {
                when (code()) {
                    200 -> {
                        body()?.run {
                            val newCfg = config.copy(
                                    vip4 = lease.vip4,
                                    vip6 = lease.vip6,
                                    leaseActiveUntil = lease.expires,
                                    blockaVpn = true
                            )
                            ktx.v("new active lease, until: ${lease.expires}")
                            ktx.emit(BLOCKA_CONFIG, newCfg)
                            scheduleRecheck(ktx, newCfg)
                        }
                    }
                    else -> {
                        ktx.e("new lease api call response ${code()}")
                        if (retry < MAX_RETRIES) newLease(ktx, config, retry + 1)
                        else clearConnectedGateway(ktx, config)
                        Unit
                    }
                }
            }
        }
    })
}

private fun scheduleRecheck(ktx: AndroidKontext, config: BlockaConfig) {
    val alarm: AlarmManager = ktx.ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    val operation = Intent(ktx.ctx, RenewLicenseReceiver::class.java).let { intent ->
        PendingIntent.getBroadcast(ktx.ctx, 0, intent, 0)
    }

    val accountTime = config.activeUntil
    val leaseTime = Date(config.leaseActiveUntil.time - 1800 * 1000) // Half an hour before lease ends
    val sooner = if (accountTime.before(leaseTime)) accountTime else leaseTime
    if (sooner.before(Date())) {
        ktx.emit(BLOCKA_CONFIG, config.copy(blockaVpn = false))
        async {
            // Wait until tunnel is off and recheck
            delay(3000)
            checkAccountInfo(ktx, config)
        }
    } else {
        alarm.set(AlarmManager.RTC, sooner.time, operation)
        ktx.v("scheduled account / lease recheck for $sooner")
    }
}

class RenewLicenseReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        async {
            val ktx = ctx.ktx("recheck")
            ktx.v("recheck account / lease task executing")
            val config = ktx.getMostRecent(BLOCKA_CONFIG)!!
            checkAccountInfo(ktx, config)
        }
    }
}

data class Request(
        val domain: String,
        val blocked: Boolean = false,
        val time: Date = Date()
) {
    override fun equals(other: Any?): Boolean {
        return if (other !is Request) false
        else domain.equals(other.domain)
    }

    override fun hashCode(): Int {
        return domain.hashCode()
    }
}
