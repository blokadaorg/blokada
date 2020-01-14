package blocka

import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import core.bits.accountInactive
import core.bits.menu.MENU_CLICK_BY_NAME_SUBMENU
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import notification.AccountInactiveNotification
import notification.LeaseExpiredNotification
import notification.notificationMain
import org.blokada.R
import tunnel.showSnack
import java.io.File

private val context = newSingleThreadContext("blocka-vpn-main") + logCoroutineExceptions()

val blockaVpnMain = runBlocking { async(context) { BlockaVpnMain() }.await() }

fun getAvatarFilePath() = File(getActiveContext()!!.filesDir, "avatar.png")

class BlockaVpnMain {
    private val accountManager: AccountManager
    private val leaseManager: LeaseManager
    private val blockaVpnManager: BlockaVpnManager
    private val boringtunLoader = BoringtunLoader()

    private val ktx by lazy { getActiveContext()!!.ktx("blocka-main") }
    private val di by lazy { ktx.di() }

    init {
        val restApi: BlockaRestApi = di.instance()

        accountManager = AccountManager(
                state = get(CurrentAccount::class.java),
                newAccountRequest = {
                    RetryingRetrofitHandler(restApi.newAccount()).execute().account.accountId
                },
                getAccountRequest = { accountId ->
                    RetryingRetrofitHandler(restApi.getAccountInfo(accountId)).execute().account.activeUntil
                },
                generateKeypair = boringtunLoader::generateKeypair,
                accountValid = {
                    notificationMain.cancel(AccountInactiveNotification())
                }
        )
        leaseManager = LeaseManager(
                state = get(CurrentLease::class.java),
                getGatewaysRequest = {
                    RetryingRetrofitHandler(restApi.getGateways()).execute().gateways
                },
                getLeasesRequest = { accountId ->
                    RetryingRetrofitHandler(restApi.getLeases(accountId)).execute().leases
                },
                newLeaseRequest = { leaseRequest ->
                    try {
                        RetryingRetrofitHandler(restApi.newLease(leaseRequest)).execute().lease
                    } catch(ex: ResponseCodeException) {
                        if (ex.code == 403) throw BlockaRestModel.TooManyDevicesException()
                        else throw ex
                    }
                },
                deleteLeaseRequest = { leaseRequest ->
                    RetryingRetrofitHandler(restApi.deleteLease(leaseRequest)).execute()
                },
                deviceAlias = defaultDeviceAlias
        )

        blockaVpnManager = BlockaVpnManager(
                enabled = get(BlockaVpnState::class.java).enabled,
                accountManager = accountManager,
                leaseManager = leaseManager,
                scheduleAccountCheck = ::scheduleAccountChecks
        )
    }

    fun enable() = async(context) {
        v("enabling blocka vpn")
        blockaVpnManager.enabled = true
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    fun disable() = async(context) {
        v("disabling blocka vpn")
        blockaVpnManager.enabled = false
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    fun restoreAccount(newId: AccountId) = async(context) {
        try {
            v("restoring account")
            blockaVpnManager.restoreAccount(newId)
            set(CurrentAccount::class.java, accountManager.state)
            v("restored account")
        } catch (ex: Exception) {
            showSnack(R.string.slot_account_name_api_error.res())
            e("failed restoring account, using old", ex)
        }
    }

    fun sync(showErrorToUser: Boolean = true) = async(context) {
        v(">> syncing")
        syncAndHandleErrors(showErrorToUser, force = true)
        v("done syncing")

        set(CurrentAccount::class.java, accountManager.state)
        set(CurrentLease::class.java, leaseManager.state)
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    fun syncIfNeeded() = async(context) {
        v(">> syncing if needed")
        val needed = blockaVpnManager.shouldSync()
        if (needed) syncAndHandleErrors(showErrorToUser = true, force = false)
        v("done syncing if needed")

        if (needed) {
            set(CurrentAccount::class.java, accountManager.state)
            set(CurrentLease::class.java, leaseManager.state)
            set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
        }
    }

    private fun syncAndHandleErrors(showErrorToUser: Boolean, force: Boolean) {
        try {
            blockaVpnManager.enabled = get(BlockaVpnState::class.java).enabled
            boringtunLoader.loadBoringtunOnce()
            blockaVpnManager.sync(force)
            boringtunLoader.throwIfBoringtunUnavailable()
        } catch (ex: Exception) {
            e("failed syncing", ex)
            if (showErrorToUser) handleException(ex)
            if (ex is BoringTunLoadException) blockaVpnManager.enabled = false
        }
        hideTunnelNotificationsIfOk()
    }

    fun deleteLease(lease: BlockaRestModel.LeaseRequest) = async(context) {
        v("deleting lease")
        leaseManager.deleteLease(accountManager.state, lease.publicKey, lease.gatewayId)
        v("done deleting lease")
    }

    fun setGatewayIfOk(gatewayId: String) = async(context) {
        v(">> setting gateway if ok", gatewayId)
        val oldGateway = leaseManager.state.gatewayId
        try {
            leaseManager.setGateway(gatewayId)
            leaseManager.sync(accountManager.state)
            v("done setting gateway")
        } catch (ex: Exception) {
            handleException(ex)
            if (oldGateway.isNotBlank()) {
                e("failed setting gateway, reverting", gatewayId, ex)
                try {
                    leaseManager.setGateway(oldGateway)
                    leaseManager.sync(accountManager.state)
                } catch (ex: Exception) {
                    e("failed reverting gateway", ex)
                }
            }
        }

        set(CurrentLease::class.java, leaseManager.state)
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    private fun handleException(ex: Exception) = when {
        ex is BlockaAccountExpired -> {
            async(UI) {
                notificationMain.show(AccountInactiveNotification())
                val ctx = getActiveContext()!!
                accountInactive(ctx)
            }
            blockaVpnManager.enabled = false
        }
        ex is BlockaTooManyDevices || ex is BlockaRestModel.TooManyDevicesException -> {
            emit(MENU_CLICK_BY_NAME_SUBMENU, R.string.menu_vpn.res() to R.string.menu_vpn_leases.res())
            showSnack(R.string.slot_too_many_leases.res())
            blockaVpnManager.enabled = false
        }
        ex is BlockaGatewayNotSelected -> {
            emit(MENU_CLICK_BY_NAME_SUBMENU, R.string.menu_vpn.res() to R.string.menu_vpn_gateways.res())
            showSnack(R.string.menu_vpn_select_gateway.res())
            blockaVpnManager.enabled = false
        }
        ex is BoringTunLoadException -> {
            if (blockaVpnManager.enabled) showSnack(R.string.home_boringtun_not_loaded.res())
            else Unit
        }
        ex is BlockaAccountEmpty -> {
            showSnack(R.string.slot_account_cant_create.res())
            blockaVpnManager.enabled = false
        }
        ex is BlockaAccountNotOk -> {
            showSnack(R.string.home_account_error.res())
        }
        ex is BlockaLeaseNotOk -> {
            notificationMain.show(LeaseExpiredNotification())
            showSnack(R.string.slot_lease_cant_connect.res())
        }
        else -> {
            showSnack(R.string.home_blocka_vpn_error.res())
        }
    }

    private fun hideTunnelNotificationsIfOk() {
        if (blockaVpnManager.enabled) {
            notificationMain.cancel(LeaseExpiredNotification())
            notificationMain.cancel(AccountInactiveNotification())
        }
    }
}
