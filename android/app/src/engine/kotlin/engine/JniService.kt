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

package engine

import com.blocka.dns.BlockaDnsJNI
import model.BlokadaException
import service.EnvironmentService

object JniService {

    fun setup() {
        try {
            System.loadLibrary("boringtun")
        } catch (ex: Throwable) {
            throw BlokadaException("Could not load boringtun", ex)
        }

        if (EnvironmentService.isLibre()) {
            try {
                System.loadLibrary("blocka_dns")
                BlockaDnsJNI.engine_logger(if (EnvironmentService.isPublicBuild()) "error" else "debug")
//        val fromBlocka = BlockaDnsJNI.create_new_dns("127.0.0.1:8573", "1.1.1.1,1.0.0.1", "cloudflare-dns.com", "dns-query")
            } catch (ex: Throwable) {
                throw BlokadaException("Could not load blocka_dns", ex)
            }
        }
    }

}