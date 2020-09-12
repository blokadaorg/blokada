package repository

import kotlinx.coroutines.delay
import model.*
import service.EnvironmentService
import java.util.*

//object BlockaDataSource {
object MockBlockaDataSource {

    suspend fun postAccount(): Account {
        delay(3000)
        return Account(id = "mockedmocked")
    }

    private var refreshCount = 0
    suspend fun getAccount(id: AccountId): Account {
        delay(3000)
        if (id.length == 12) {
            return Account(
                id = id,
                active_until = if (refreshCount++ % 2 != 0) Date().plus(3) else Date(0)
            )
        } else throw BlokadaException("Bad account")
    }

    suspend fun getGateways(): List<Gateway> {
        delay(3000)
        return listOf(
            Gateway.mocked("London"),
            Gateway.mocked("Los Angeles"),
            Gateway.mocked("Montreal"),
            Gateway.mocked("New York"),
            Gateway.mocked("Stockholm"),
            Gateway.mocked("Tokyo")
        )
    }

    suspend fun getLeases(id: AccountId): List<Lease> {
        delay(2000)
        return listOf<Lease>(
            Lease.mocked("John Doe's Android Device"),
            Lease.mocked("Papa Roach's iPad")
        )
    }

    suspend fun postLease(request: LeaseRequest): Lease {
        delay(1000)
        return Lease(
            account_id = request.account_id,
            public_key = request.public_key,
            gateway_id = request.gateway_id,
            expires = Date().plus(1),
            alias = EnvironmentService.getDeviceAlias(),
            vip4 = "0.0.0.0",
            vip6 = ":"
        )
    }

    suspend fun deleteLease(request: LeaseRequest) {

    }

}