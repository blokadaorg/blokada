/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import com.blocka.dns.BlockaDnsJNI
import model.BlokadaException
import service.EnvironmentService
import utils.Logger

object JniService {

    private val log = Logger("JniService")

    fun setup() {
        try {
            System.loadLibrary("blocka_dns")
        } catch (ex: Throwable) {
            throw BlokadaException("Could not load blocka_dns", ex)
        }

        try {
            System.loadLibrary("boringtun")
        } catch (ex: Throwable) {
            throw BlokadaException("Could not load boringtun", ex)
        }

        BlockaDnsJNI.engine_logger(if (EnvironmentService.isPublicBuild()) "error" else "debug")

//        val fromBlocka = BlockaDnsJNI.create_new_dns("127.0.0.1:8573", "1.1.1.1,1.0.0.1", "cloudflare-dns.com", "dns-query")
    }

}