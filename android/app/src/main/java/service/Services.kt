/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

object Services {

    val context by lazy { ContextService }
    val apiForCurrentUser by lazy { BlockaApiForCurrentUserService }
    val sheet by lazy { SheetService() }
    val payment: IPaymentService by lazy { BillingService() }
    val biometric by lazy { BiometricService() }

}