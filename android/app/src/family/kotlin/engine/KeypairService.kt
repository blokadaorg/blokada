/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2024 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import model.PrivateKey
import model.PublicKey

object KeypairService {
    fun newKeypair(): Pair<PrivateKey, PublicKey> {
        throw Exception("Family does not support keypair generation")
    }
}