package blocka

import android.content.Intent
import com.cloudflare.app.boringtun.BoringTunJNI
import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import core.bits.menu.MENU_CLICK_BY_NAME_SUBMENU
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import notification.displayAccountExpiredNotification
import notification.displayLeaseExpiredNotification
import org.blokada.R
import tunnel.RestApi
import tunnel.RestModel
import tunnel.showSnack

private val context = newSingleThreadContext("blocka-vpn-main") + logCoroutineExceptions()

val blockaVpnMain = runBlocking { async(context) { BlockaVpnMain() }.await() }

class BlockaVpnMain {
    private val accountManager: AccountManager
    private val leaseManager: LeaseManager
    private val blockaVpnManager: BlockaVpnManager
    private val boringtunLoader = BoringtunLoader()

    private val ktx by lazy { getActiveContext()!!.ktx("blocka-main") }
    private val di by lazy { ktx.di() }

    init {
        val restApi: RestApi = di.instance()

        registerPersistenceForAccount()

        accountManager = AccountManager(
                state = get(CurrentAccount::class.java),
                newAccountRequest = {
                    RetryingRetrofitHandler(restApi.newAccount()).execute().account.accountId
                },
                getAccountRequest = { accountId ->
                    RetryingRetrofitHandler(restApi.getAccountInfo(accountId)).execute().account.activeUntil
                },
                generateKeypair = {
                    boringtunLoader.loadBoringtunOnce()
                    try {
                        val secret = BoringTunJNI.x25519_secret_key()
                        val public = BoringTunJNI.x25519_public_key(secret)
                        val secretString = BoringTunJNI.x25519_key_to_base64(secret)
                        val publicString = BoringTunJNI.x25519_key_to_base64(public)
                        secretString to publicString
                    } catch (ex: Exception) {
                        throw BoringTunLoadException("failed generating user keys", ex)
                    }
                }
        )
var i = 0
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
                        if (ex.code == 403) throw RestModel.TooManyDevicesException()
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
        try {
            blockaVpnManager.enabled = get(BlockaVpnState::class.java).enabled
            if (blockaVpnManager.enabled) {
                boringtunLoader.loadBoringtunOnce()
                blockaVpnManager.sync()
            }
        } catch (ex: Exception) {
            e("failed syncing", ex)
            if (showErrorToUser) handleException(ex)
        }
        v("done syncing")

        set(CurrentAccount::class.java, accountManager.state)
        set(CurrentLease::class.java, leaseManager.state)
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    fun syncIfNeeded() = async(context) {
        v(">> syncing if needed")
        val needed = blockaVpnManager.shouldSync()
        if (needed) {
            try {
                boringtunLoader.loadBoringtunOnce()
                blockaVpnManager.sync()
            } catch (ex: Exception) {
                e("failed syncing", ex)
                handleException(ex)
            }
        }
        v("done syncing if needed")

        if (needed) {
            set(CurrentAccount::class.java, accountManager.state)
            set(CurrentLease::class.java, leaseManager.state)
            set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
        }
    }

    fun deleteLease(lease: RestModel.LeaseRequest) = async(context) {
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
            e("failed setting gateway, reverting", gatewayId, ex)
            handleException(ex)
            try {
                leaseManager.setGateway(oldGateway)
                leaseManager.sync(accountManager.state)
            } catch (ex: Exception) {
                e("failed reverting gateway", ex)
            }
        }

        set(CurrentLease::class.java, leaseManager.state)
        set(BlockaVpnState::class.java, BlockaVpnState(blockaVpnManager.enabled))
    }

    private fun handleException(ex: Exception) = when {
        ex is BlockaAccountExpired -> {
            async(UI) {
                val ctx = getActiveContext()!!
                displayAccountExpiredNotification(ctx)
                modalManager.openModal()
                ctx.startActivity(Intent(ctx, SubscriptionActivity::class.java).run {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                showSnack(R.string.account_inactive.res())
            }
            blockaVpnManager.enabled = false
        }
        ex is BlockaTooManyDevices || ex is RestModel.TooManyDevicesException -> {
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
            showSnack(R.string.home_boringtun_not_loaded.res())
            blockaVpnManager.enabled = false
        }
        ex is BlockaAccountEmpty -> {
            showSnack(R.string.slot_account_cant_create.res())
            blockaVpnManager.enabled = false
        }
        ex is BlockaAccountNotOk -> {
            showSnack(R.string.home_account_error.res())
        }
        ex is BlockaLeaseNotOk -> {
            val ctx = getActiveContext()!!
            displayLeaseExpiredNotification(ctx)
            showSnack(R.string.slot_lease_cant_connect.res())
        }
        else -> {
            showSnack(R.string.home_blocka_vpn_error.res())
        }
    }
}
