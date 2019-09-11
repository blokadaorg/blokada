package blocka

import core.PaperSource
import core.Register
import core.ktx
import core.v
import tunnel.Persistence

fun registerPersistenceForAccount() {
    // Reads legacy BlockaConfig and migrates account info if needed
    Register.sourceFor(CurrentAccount::class.java, default = CurrentAccount(),
            source = object : PaperSource<CurrentAccount>("current-account") {
                override fun <T> get(classOfT: Class<T>, id: String?): T? {
                    val new = super.get(classOfT, id)
                    new as CurrentAccount?
                    return if ((new?.migration ?: 0) == 0) {
                        val legacy = Persistence.blocka.load("legacy".ktx())
                        if (legacy.accountId.isNotBlank()) {
                            v("migrating BlockaConfig to CurrentAccount")
                            CurrentAccount(
                                    id = legacy.accountId,
                                    publicKey = legacy.publicKey,
                                    activeUntil = legacy.activeUntil,
                                    lastAccountCheck = legacy.lastDaily,
                                    accountOk = true,
                                    migration = 1
                            ) as T?
                        } else new?.copy(migration = 1) as T?
                    } else new
                }
            }
    )

    // Reads legacy BlockaConfig and migrates lease info if needed
    Register.sourceFor(CurrentLease::class.java, default = CurrentLease(),
            source = object : PaperSource<CurrentLease>("current-lease") {
                override fun <T> get(classOfT: Class<T>, id: String?): T? {
                    val new = super.get(classOfT, id)
                    new as CurrentLease?
                    return if ((new?.migration ?: 0) == 0) {
                        val legacy = Persistence.blocka.load("legacy".ktx())
                        if (legacy.gatewayId.isNotBlank()) {
                            v("migrating BlockaConfig to CurrentLease")
                            CurrentLease(
                                    gatewayId = legacy.gatewayId,
                                    gatewayIp = legacy.gatewayIp,
                                    gatewayPort = legacy.gatewayPort,
                                    gatewayNiceName = legacy.gatewayNiceName,
                                    vip4 = legacy.vip4,
                                    vip6 = legacy.vip6,
                                    leaseActiveUntil = legacy.leaseActiveUntil,
                                    leaseOk = true,
                                    migration = 1
                            ) as T?
                        } else new?.copy(migration = 1) as T?
                    } else new
                }
            }
    )
}
