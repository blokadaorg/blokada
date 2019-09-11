package blocka

import core.v

internal class AccountManager(
        internal var state: CurrentAccount,
        val newAccountRequest: () -> AccountId? = { throw Exception("not implemented") },
        val getAccountRequest: (AccountId) -> ActiveUntil = { throw Exception("not implemented") },
        val generateKeypair: () -> Pair<String, String> = { throw Exception("not implemented") }
) {

    private var lastAccountRequest = 0L

    fun sync() {
        when {
            state.id.isBlank() -> {
                // New account
                val id = newAccountRequest()
                if (id?.isBlank() != false) throw Exception("failed to request new account")
                state = state.copy(
                        id = id,
                        accountOk = false
                )
            }
            lastAccountRequest + 3600 * 1000 > System.currentTimeMillis() -> {
                v("skipping account request, done one recently")
            }
            else -> {
                try {
                    val activeUntil = getAccountRequest(state.id)
                    state = state.copy(
                            activeUntil = activeUntil,
                            accountOk = !activeUntil.expired()
                    )
                    lastAccountRequest = System.currentTimeMillis()
                } catch (ex: Exception) {
                    state = state.copy(accountOk = false)
                    throw Exception("failed to get account request", ex)
                }
            }
        }
    }

    fun restoreAccount(newId: AccountId) {
        val activeUntil = getAccountRequest(newId)
        state = state.copy(
                id = newId,
                activeUntil = activeUntil,
                accountOk = true
        )
    }

    fun ensureKeypair() {
        if (state.publicKey.isNotBlank() and state.privateKey.isNotBlank()) return
        val (private, public) = generateKeypair()
        state = state.copy(
                privateKey = private,
                publicKey = public
        )
    }
}
