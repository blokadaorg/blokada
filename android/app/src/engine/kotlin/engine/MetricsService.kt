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

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import ui.utils.now
import utils.Logger
import java.net.InetSocketAddress
import java.net.Socket

object MetricsService {

    private val log = Logger("Metrics")
    private val scope = GlobalScope

    private lateinit var onNoConnectivity: () -> Unit

    private var hadAtLeastOneSuccessfulQuery = false
    private const val MAX_ONE_WAY_DNS_REQUESTS = 10
    private var oneWayDnsCounter = 0

    private var queryCount = 0
    private var printEveryXQuery = 1

    private var id: Short? = null
    private var lastTimestamp = 0L

    var lastRtt = 0L
        @Synchronized get
        @Synchronized set

    fun onDnsQueryStarted(sequence: Short) {
        if (hadAtLeastOneSuccessfulQuery && ++oneWayDnsCounter > MAX_ONE_WAY_DNS_REQUESTS) {
            log.e("Connectivity lost, too many DNS requests without a response")
            onNoConnectivity()
        }

        if (id == null) {
            id = sequence
            lastTimestamp = now()
        }
    }

    fun onDnsQueryFinished(sequence: Short) {
        oneWayDnsCounter = 0
        if (sequence == id) {
            lastRtt = now() - lastTimestamp
            id = null

            if ((++queryCount % printEveryXQuery) == 0) {
                log.v("DNS query RTT: ${lastRtt}ms (${printEveryXQuery - 1} skipped printing)")
                printEveryXQuery++
                queryCount = 0
            }
        }
    }

    fun startMetrics(onNoConnectivity: () -> Unit) {
        log.v("Started metrics")

        id = null
        lastTimestamp = 0L
        hadAtLeastOneSuccessfulQuery = false
        this.onNoConnectivity = onNoConnectivity
        queryCount = 0
        printEveryXQuery = 1
        oneWayDnsCounter = 0
        lastRtt = 9999 // To signal connection problems in case we don't get any response soon

        // Those connectivity check methods do not work very well so far.
        hadAtLeastOneSuccessfulQuery = true
        //testConnectivityActive()
        //testConnectivityPassive()
    }

    private fun testConnectivityActive() {
        scope.launch(Dispatchers.IO) {
            val socket = Socket()
            try {
                socket.soTimeout = 3000
                socket.connect(InetSocketAddress("blokada.org", 80), 3000);
                hadAtLeastOneSuccessfulQuery = true
            } catch (e: Exception) {
                log.e("Timeout pinging home")
                onNoConnectivity()
            } finally {
                try { socket.close() } catch (e: Exception) {}
            }
        }
    }

    private fun testConnectivityPassive() {
        scope.launch(Dispatchers.IO) {
            delay(5000)
            if (lastRtt < 9999) {
                log.e("Timeout waiting for the first successful query")
                onNoConnectivity()
            } else {
                hadAtLeastOneSuccessfulQuery = true
            }
        }
    }

}