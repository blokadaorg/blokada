/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.distinctUntilChanged
import androidx.lifecycle.map
import channel.account.Account
import channel.account.AccountOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import model.toAccountType
import service.FlutterService
import utils.toBlockaDate
import java.util.Date

fun Account?.getType() = this?.type.toAccountType()
fun Account.activeUntil(): Date = activeUntil?.toBlockaDate() ?: Date(0)

object AccountBinding: AccountOps {
    val account = MutableStateFlow<Account?>(null)
    val live = MutableLiveData<Account>()
    val expiration: LiveData<Date> = live.map { it.activeUntil() }.distinctUntilChanged()

    private val flutter by lazy { FlutterService }
    private val scope = GlobalScope

    init {
        AccountOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            account.collect { live.postValue(it) }
        }
    }

    override fun doAccountChanged(account: Account, callback: (Result<Unit>) -> Unit) {
        this.account.value = account
        callback(Result.success(Unit))
    }
}