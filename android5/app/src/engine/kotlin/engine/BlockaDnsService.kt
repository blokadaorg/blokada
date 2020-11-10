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

package newengine

import com.blocka.dns.BlockaDnsJNI
import model.BlokadaException
import model.Dns
import model.isDnsOverHttps
import utils.Logger

object BlockaDnsService {

    const val PROXY_PORT: Short = 8573

    private val log = Logger("BlockaDns")
    private var started = false

    fun startDnsProxy(dns: Dns) {
        log.v("Starting DoH DNS proxy")
        if (!dns.isDnsOverHttps()) throw BlokadaException("Attempted to start DoH DNS proxy for non-DoH dns entry")
        val name = dns.name!!
        val path = dns.path!!

        BlockaDnsJNI.create_new_dns(
            listen_addr = "127.0.0.1:$PROXY_PORT",
            dns_ips = dns.ips.joinToString(","),
            dns_name = name,
            dns_path = path
        )
        started = true
    }

    fun stopDnsProxy() {
        if (started) {
            started = false
            log.v("Stopping DoH DNS proxy")
            BlockaDnsJNI.dns_close(0)
        }
    }

}