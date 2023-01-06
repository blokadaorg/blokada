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

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.BlokadaException
import repository.Repos
import ui.utils.cause
import ui.utils.now
import utils.LoggerWithThread
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Monitoring performance of a packet loop (any implementation).
 *
 * Will measure DNS query RTT, and count recoverable errors (like network IO errors). If too many
 * errors happen in a short amount of time, it fire onNoConnectivity() event (and cause a restart by
 * PacketLoopService).
 */
object MetricsService {

    internal const val PACKET_BUFFER_SIZE = 1600

    private const val MAX_ONE_WAY_DNS_REQUESTS = 15
    private const val MAX_RECENT_ERRORS = 15

    private val log = LoggerWithThread("Metrics")
    private val scope = GlobalScope

    private val processingRepo by lazy { Repos.processing }

    private lateinit var onNoConnectivity: () -> Unit

    private var hadAtLeastOneSuccessfulQuery = false
    private var oneWayDnsCounter = 0

    private var queryCounter = 0
    private var printEveryXQuery = 1

    private var cleanLoopCounter = 0
    private var errorCounterBeforeLoop = 0
    private var errorCounter = 0

    private var id: Short? = null
    private var lastTimestamp = 0L

    var lastRtt = 0L
        @Synchronized get
        @Synchronized set

    fun onLoopEnter() {
        errorCounterBeforeLoop = errorCounter
    }

    fun onLoopExit() {
        if (errorCounter == 0) return

        if (errorCounterBeforeLoop == errorCounter) {
            cleanLoopCounter++
        } else {
            cleanLoopCounter = 0
        }

        if (cleanLoopCounter >= MAX_RECENT_ERRORS / 2) {
            log.v("Loop running clean, resetting errorCounter")
            errorCounter = 0
            cleanLoopCounter = 0
            GlobalScope.launch { processingRepo.reportConnIssues("loop", experiencing = false) }
        }
    }

    fun onRecoverableError(ex: BlokadaException) {
        log.w("Recoverable error occurred (${++errorCounter}): ${ex.localizedMessage}")
        if (errorCounter >= MAX_RECENT_ERRORS) {
            log.e("Connectivity lost, too many errors recently".cause(ex))
            onNoConnectivity()
            GlobalScope.launch { processingRepo.reportConnIssues("loop", experiencing = true) }
        }
    }

    fun onDnsQueryStarted(sequence: Short) {
        if (hadAtLeastOneSuccessfulQuery && ++oneWayDnsCounter >= MAX_ONE_WAY_DNS_REQUESTS) {
            log.e("Connectivity lost, $oneWayDnsCounter DNS requests without a response")
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

            if ((++queryCounter % printEveryXQuery) == 0) {
                log.v("DNS-RTT/DNS-ERR/REC-ERR: ${lastRtt}ms/$oneWayDnsCounter/$errorCounter")
                if (printEveryXQuery < 30) printEveryXQuery++
                queryCounter = 0
            }
        }
    }

    fun startMetrics(onNoConnectivity: () -> Unit) {
        log.v("Started metrics")

        id = null
        lastTimestamp = 0L
        hadAtLeastOneSuccessfulQuery = false
        this.onNoConnectivity = onNoConnectivity
        queryCounter = 0
        printEveryXQuery = 1
        oneWayDnsCounter = 0
        cleanLoopCounter = 0
        errorCounter = 0
        errorCounterBeforeLoop = 0
        lastRtt = 9999 // To signal connection problems in case we don't get any response soon

        // Those connectivity check methods do not work very well so far.
        hadAtLeastOneSuccessfulQuery = true
        //testConnectivityActive()
        //testConnectivityPassive()
    }

    fun stopMetrics() {
        GlobalScope.launch { processingRepo.reportConnIssues("loop", experiencing = false) }
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