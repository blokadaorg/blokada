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