package blocka

import core.v

internal class LeaseManager(
    internal var state: CurrentLease,
    val getGatewaysRequest: () -> List<BlockaRestModel.GatewayInfo> = { throw Exception("not implemented") },
    val getLeasesRequest: (AccountId) -> List<BlockaRestModel.LeaseInfo> = { throw Exception("not implemented") },
    val newLeaseRequest: (BlockaRestModel.LeaseRequest) -> BlockaRestModel.LeaseInfo = {
        throw Exception(
            "not implemented"
        )
    },
    val deleteLeaseRequest: (BlockaRestModel.LeaseRequest) -> Any = { throw Exception("not implemented") },
    val deviceAlias: String = "unknown device"
) {
    fun sync(account: CurrentAccount) {
        val gateways = getGatewaysRequest()
        val currentGateway = gateways.firstOrNull { it.publicKey == state.gatewayId }
        if (currentGateway != null) {
            v("found current gateway", currentGateway)
            state = state.copy(
                gatewayIp = currentGateway.ipv4,
                gatewayPort = currentGateway.port,
                gatewayNiceName = currentGateway.niceName()
            )

            val leases = getLeasesRequest(account.id)
            val currentLease = leases.firstOrNull {
                it.publicKey == account.publicKey && it.gatewayId == state.gatewayId
            }
            if (currentLease != null && !currentLease.expiresSoon()) {
                v("found active lease", currentLease)
                state = state.copy(
                    vip4 = currentLease.vip4,
                    vip6 = currentLease.vip6,
                    leaseActiveUntil = currentLease.expires,
                    leaseOk = true
                )
                // schedule recheck
            } else {
                v("no active lease, trying to create a new one")
                try {
                    val lease = newLeaseRequest(
                        BlockaRestModel.LeaseRequest(
                            accountId = account.id,
                            publicKey = account.publicKey,
                            gatewayId = state.gatewayId,
                            alias = deviceAlias
                        )
                    )
                    state = state.copy(
                        vip4 = lease.vip4,
                        vip6 = lease.vip6,
                        leaseActiveUntil = lease.expires,
                        leaseOk = true
                    )
                    v("created new lease", lease)
                } catch (ex: Exception) {
                    state = state.copy(leaseOk = false)
                    throw ex
                }
            }
        } else {
            v("no current gateway, user needs to select")
            state = state.copy(leaseOk = false)
            throw BlockaGatewayNotSelected()
        }
    }

    fun setGateway(gatewayId: String) {
        state = state.copy(
            gatewayId = gatewayId,
            leaseOk = false
        )
    }

    fun deleteLease(account: CurrentAccount, publicKey: String, gatewayId: String) {
        deleteLeaseRequest(
            BlockaRestModel.LeaseRequest(
                accountId = account.id,
                publicKey = publicKey,
                gatewayId = gatewayId,
                alias = ""
            )
        )
    }
}
