package blocka

import java.util.*

internal class BlockaVpnManager(
    internal var enabled: Boolean,
    private val accountManager: AccountManager,
    private val leaseManager: LeaseManager,
    private val scheduleAccountCheck: () -> Any
) {

    fun restoreAccount(newId: AccountId) {
        accountManager.restoreAccount(newId)
    }

    fun sync(force: Boolean = false) {
        try {
            accountManager.sync(force)
            if (!enabled) return
            leaseManager.sync(accountManager.state)
            //enabled = enabled && (accountManager.state.accountOk && leaseManager.state.leaseOk)
            val isOk = accountManager.state.accountOk && leaseManager.state.leaseOk
            if (isOk) scheduleAccountCheck()
        } catch (ex: Exception) {
            //enabled = false
            when {
                ex is BoringTunLoadException -> throw ex
                accountManager.state.activeUntil.expired() && enabled -> throw BlockaAccountExpired()
                ex is BlockaRestModel.TooManyDevicesException -> throw BlockaTooManyDevices()
                ex is BlockaGatewayNotSelected -> throw ex
                accountManager.state.id.isBlank() -> throw BlockaAccountEmpty()
                !accountManager.state.accountOk -> throw BlockaAccountNotOk()
                !leaseManager.state.leaseOk -> throw BlockaLeaseNotOk()
            }

            throw Exception("failed syncing blocka vpn", ex)
        }
    }

    fun shouldSync() =
        accountManager.state.id.isEmpty() || leaseManager.state.leaseActiveUntil.before(Date())
}

class BlockaAccountExpired : Exception()
class BlockaAccountEmpty : Exception()
class BlockaAccountNotOk : Exception()
class BlockaLeaseNotOk : Exception()
class BlockaGatewayNotSelected : Exception()
class BlockaTooManyDevices : Exception()
