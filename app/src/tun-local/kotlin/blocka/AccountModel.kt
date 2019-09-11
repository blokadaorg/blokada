package blocka

import android.os.Build
import tunnel.EXPIRATION_OFFSET
import java.util.*

data class CurrentAccount(
        val id: String = "",
        val activeUntil: Date = Date(0),
        val privateKey: String = "",
        val publicKey: String = "",
        val lastAccountCheck: Long = 0,
        val accountOk: Boolean = false,
        val migration: Int = 0,
        val unsupportedForVersionCode: Int = 0
) {
    override fun toString(): String {
        return "CurrentAccount(id='$id', activeUntil=$activeUntil, publicKey='$publicKey', lastAccountCheck=$lastAccountCheck, accountOk=$accountOk, migration=$migration)"
    }
}

data class CurrentLease(
        val gatewayId: String = "",
        val gatewayIp: String = "",
        val gatewayPort: Int = 0,
        val gatewayNiceName: String = "",
        val vip4: String = "",
        val vip6: String = "",
        val leaseActiveUntil: Date = Date(0),
        val leaseOk: Boolean = false,
        val migration: Int = 0
)

data class BlockaVpnState(
        val enabled: Boolean
)


typealias AccountId = String
typealias ActiveUntil = Date

fun ActiveUntil.expiresSoon() = this.before(Date(Date().time + EXPIRATION_OFFSET))
fun ActiveUntil.expired() = this.before(Date())

internal val defaultDeviceAlias = "%s-%s".format(Build.MANUFACTURER, Build.DEVICE)
