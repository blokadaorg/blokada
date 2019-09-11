package blocka

import core.LOGGER_TEST
import org.junit.Assert
import org.junit.Test
import tunnel.*
import java.util.*

fun tomorrow() = Date(Date().time + 86400)

class AccountTest {
    init {
        LOGGER_TEST = true
    }

    @Test fun accountManager_firstSyncWillRequestNewAccount() {
        val mgr = AccountManager(
                state = CurrentAccount(),
                newAccountRequest = { "generated-id" },
                generateKeypair = { "private-key" to "public-key" }
        )

        mgr.sync()

        Assert.assertEquals(true, mgr.state.accountOk)
        Assert.assertEquals("generated-id", mgr.state.id)
        Assert.assertEquals("private-key", mgr.state.privateKey)
        Assert.assertEquals("public-key", mgr.state.publicKey)
        Assert.assertFalse(mgr.state.activeUntil.after(Date()))

    }

    @Test fun accountManager_secondSyncWillCheckAccountExpiration() {
        val mgr = AccountManager(
                state = CurrentAccount(accountOk = true, id = "generated-id"),
                getAccountRequest = { id ->
                    Assert.assertEquals("generated-id", id)
                    tomorrow()
                },
                generateKeypair = { "private-key" to "public-key" }
        )

        mgr.sync()

        Assert.assertEquals(true, mgr.state.accountOk)
        Assert.assertTrue(mgr.state.activeUntil.after(Date()))
    }


    @Test fun accountManager_getAccountRequestFails() {
        val mgr = AccountManager(
                state = CurrentAccount(id = "id", accountOk = true),
                getAccountRequest = { id ->
                    throw Exception("get account request failed")
                }
        )

        runCatching { mgr.sync() }
        Assert.assertEquals(false, mgr.state.accountOk)
    }

    @Test fun accountManager_restoreAccount() {
        val mgr = AccountManager(
                state = CurrentAccount(
                        id = "old-id",
                        activeUntil = Date(0),
                        privateKey = "private-key",
                        publicKey = "public-key",
                        lastAccountCheck = 0,
                        accountOk = true
                ),
                getAccountRequest = { id ->
                    Assert.assertEquals("new-id", id)
                    tomorrow()
                }
        )

        mgr.restoreAccount("new-id")

        Assert.assertEquals("new-id", mgr.state.id)
        Assert.assertEquals(true, mgr.state.accountOk)
    }

    @Test fun accountManager_restoreAccountRequestFails() {
        // Scenario: restore account goes bad
        val mgr = AccountManager(
                state = CurrentAccount(id = "old-id", accountOk = true),
                getAccountRequest = { id ->
                    throw Exception("unacceptable account id")
                }
        )

        try { mgr.restoreAccount("bad-id") } catch (ex: Exception) {}

        Assert.assertEquals("old-id", mgr.state.id)
        Assert.assertEquals(true, mgr.state.accountOk)
    }

    private val gatewaysRequest = { listOf(
            RestModel.GatewayInfo("key1", "EU", "PL", 0, "gw1", "gw1-6", 69, Date(0)),
            RestModel.GatewayInfo("key2", "Asia", "SG", 0, "gw2", "gw2-6", 69, Date(0))
    )}

    private val user = CurrentAccount("new-id", Date(0), "prv", "user-public-key", 0L, true)

    @Test fun leaseManager_noGatewaySelected() {
        val mgr = LeaseManager(
                state = CurrentLease(),
                getGatewaysRequest = gatewaysRequest
        )

        mgr.sync(user)

        Assert.assertEquals(false, mgr.state.leaseOk)
    }

    @Test fun leaseManager_checkValidLease() {
        // Scenario: user selected gateway before, requests confirm it
        val mgr = LeaseManager(
                state = CurrentLease(
                        gatewayId = "key1",
                        leaseOk = false
                ),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { id ->
                    Assert.assertEquals("new-id", id)
                    listOf(
                            RestModel.LeaseInfo(
                                    accountId = "new-id",
                                    publicKey = "user-public-key",
                                    gatewayId = "key1",
                                    expires = tomorrow(),
                                    alias = "funny-phone",
                                    vip4 = "vip4-gw1",
                                    vip6 = "ipv6"
                            )
                    )
                }
        )

        mgr.sync(user)

        Assert.assertEquals(true, mgr.state.leaseOk)
        Assert.assertEquals("key1", mgr.state.gatewayId)
        Assert.assertEquals("gw1", mgr.state.gatewayIp)
        Assert.assertEquals("vip4-gw1", mgr.state.vip4)

    }

    @Test fun leaseManager_renewExpiredLease() {
        // Scenario: lease expired, should renew automatically
        val mgr = LeaseManager(
                state = CurrentLease(
                        gatewayId = "key1",
                        leaseActiveUntil = Date(),
                        leaseOk = true
                ),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { id -> emptyList() },
                newLeaseRequest = { request ->
                    Assert.assertEquals("new-id", request.accountId)
                    Assert.assertEquals("user-public-key", request.publicKey)
                    Assert.assertEquals("key1", request.gatewayId)
                    RestModel.LeaseInfo(
                            accountId = "new-id",
                            publicKey = "user-public-key",
                            gatewayId = "key1",
                            expires = tomorrow(),
                            alias = null,
                            vip4 = "vip4-gw1-2",
                            vip6 = "vip6-gw"
                    )
                }
        )

        mgr.sync(user)

        Assert.assertEquals("gw1", mgr.state.gatewayIp)
        Assert.assertEquals("vip4-gw1-2", mgr.state.vip4)
        Assert.assertTrue(mgr.state.leaseActiveUntil.after(Date()))

    }

    @Test(expected = Exception::class) fun leaseManager_gatewaysRequestFails() {
        val mgr = LeaseManager(
                state = CurrentLease(leaseOk = true),
                getGatewaysRequest = { throw Exception("failed gateways request") }
        )

        try {
            mgr.sync(user)
        } catch (ex: Exception) {
            // Failing gateways request does not affect if our lease is ok
            Assert.assertEquals(true, mgr.state.leaseOk)
            throw ex
        }
    }

    @Test(expected = Exception::class) fun leaseManager_leaseRequestFails() {
        val mgr = LeaseManager(
                state = CurrentLease(gatewayId = "key1", leaseOk = true, leaseActiveUntil = Date(0)),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { throw Exception("failed lease request") }
        )

        try {
            mgr.sync(user)
        } catch (ex: Exception) {
            // Failing leases request marks our lease invalid, if our lease is expired
            Assert.assertEquals(false, mgr.state.leaseOk)
            throw ex
        }
    }

    @Test fun leaseManager_leaseRequestFailsButExistingLeaseIsValid() {
        val mgr = LeaseManager(
                state = CurrentLease(gatewayId = "key1", leaseOk = true, leaseActiveUntil = tomorrow()),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { throw Exception("failed lease request") }
        )

        runCatching { mgr.sync(user) }

        Assert.assertEquals(true, mgr.state.leaseOk)
    }

    @Test(expected = Exception::class) fun leaseManager_newLeaseRequestFails() {
        val mgr = LeaseManager(
                state = CurrentLease(gatewayId = "key1", leaseOk = true, leaseActiveUntil = Date(0)),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { id -> emptyList() },
                newLeaseRequest = { request -> throw Exception("failed new lease request") }
        )

        try {
            mgr.sync(user)
        } catch (ex: Exception) {
            Assert.assertEquals(false, mgr.state.leaseOk)
            throw ex
        }
    }

    @Test(expected = RestModel.TooManyDevicesException::class) fun leaseManager_tooManyDevices() {
        val mgr = LeaseManager(
                state = CurrentLease(gatewayId = "key1"),
                getGatewaysRequest = gatewaysRequest,
                getLeasesRequest = { id -> emptyList() },
                newLeaseRequest = { request -> throw RestModel.TooManyDevicesException() }
        )

        mgr.sync(user)
    }
}

