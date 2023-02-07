/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import model.Account
import org.junit.Assert
import org.junit.Test
import java.util.*

class SerializationServiceTest {
    @Test fun basic() {
        val acc = Account(
            id = "mockedmocked",
            active_until = Date(1),
            active = false,
            type = "mocked",
            payment_source = null
        )

        val json = JsonSerializationService.serialize(acc)
        val deserialized = JsonSerializationService.deserialize(json, Account::class)

        Assert.assertEquals(Date(1), deserialized.active_until)
        Assert.assertEquals("mocked", deserialized.type)
    }
}