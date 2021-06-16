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

import model.BlokadaException
import model.Dns
import model.Gateway
import model.PrivateKey
import service.ConnectivityService
import service.DozeService
import utils.Logger
import java.net.DatagramSocket

object PacketLoopService {

    private val log = Logger("PacketLoop")
    private val connectivity = ConnectivityService
    private val doze = DozeService

    var onCreateSocket = {
        log.e("Created unprotected socket for the packet loop")
        DatagramSocket()
    }

    var onStoppedUnexpectedly = {
        log.e("Thread stopped unexpectedly, but nobody listening")
    }

    private var loop: Pair<PacketLoopConfig, Thread?>? = null
        @Synchronized get
        @Synchronized set

    init {
        connectivity.onConnectivityChanged = { isConected ->
            if (isConected) {
                loop?.let {
                    val (config, thread) = it
                    if (thread == null) {
                        log.w("Connectivity back, recreating packet loop")
                        loop = createLoop(config)
                        startSupportingServices(config)
                    }
                }
            }
        }
    }

    suspend fun startLibreMode(useDoh: Boolean, dns: Dns, tunnelConfig: SystemTunnelConfig) {
        log.v("Requested to start packet loop (libre mode)")
        if (loop != null) {
            log.w("Packet loop thread already running, stopping")
            stop()
        }

        val cfg = PacketLoopConfig(false, dns, useDoh, tunnelConfig)
        loop = createLoop(cfg)
        startSupportingServices(cfg)
    }

    suspend fun startPlusMode(useDoh: Boolean, dns: Dns, tunnelConfig: SystemTunnelConfig,
                              privateKey: PrivateKey, gateway: Gateway) {
        log.v("Requested to start packet loop for gateway: ${gateway.niceName()}")
        if (loop != null) {
            log.w("Packet loop thread already running, stopping")
            stop()
        }

        val cfg = PacketLoopConfig(true, dns, useDoh, tunnelConfig, privateKey, gateway)
        loop = createLoop(cfg)
        startSupportingServices(cfg)
    }

    suspend fun startSlimMode(useDoh: Boolean, dns: Dns, tunnelConfig: SystemTunnelConfig) {
        log.v("Requested to start packet loop (slim mode)")
        if (loop != null) {
            log.w("Packet loop thread already running, stopping")
            stop()
        }

        val cfg = PacketLoopConfig(false, dns, useDoh, tunnelConfig, useFiltering = false)
        loop = createLoop(cfg)
        startSupportingServices(cfg)
    }

    private fun createLoop(config: PacketLoopConfig): Pair<PacketLoopConfig, Thread> {
        val thread = when {
            config.usePlusMode && config.useDoh -> {
                val gw = config.requireGateway()
                PacketLoopForPlusDoh(
                    deviceIn = config.tunnelConfig.deviceIn,
                    deviceOut = config.tunnelConfig.deviceOut,
                    userBoringtunPrivateKey = config.requirePrivateKey(),
                    gatewayId = gw.public_key,
                    gatewayIp = gw.ipv4,
                    gatewayPort = gw.port,
                    createSocket = onCreateSocket,
                    stoppedUnexpectedly = this::stopUnexpectedly
                )
            }
            config.usePlusMode -> {
                val gw = config.requireGateway()
                PacketLoopForPlus(
                    deviceIn = config.tunnelConfig.deviceIn,
                    deviceOut = config.tunnelConfig.deviceOut,
                    userBoringtunPrivateKey = config.requirePrivateKey(),
                    gatewayId = gw.public_key,
                    gatewayIp = gw.ipv4,
                    gatewayPort = gw.port,
                    createSocket = onCreateSocket,
                    stoppedUnexpectedly = this::stopUnexpectedly
                )
            }
            else -> {
                PacketLoopForLibre(
                    deviceIn = config.tunnelConfig.deviceIn,
                    deviceOut = config.tunnelConfig.deviceOut,
                    createSocket = onCreateSocket,
                    stoppedUnexpectedly = this::stopUnexpectedly,
                    filter = config.useFiltering
                )
            }
        }

        thread.start()
        return config to thread
    }

    private fun startSupportingServices(config: PacketLoopConfig) {
        MetricsService.startMetrics(
            onNoConnectivity = this::stopUnexpectedly
        )
    }

    private fun stopUnexpectedly() {
        loop?.let {
            log.w("Packet loop stopped unexpectedly")
            val (config, thread) = it
            if (thread != null) {
                thread.interrupt()
                if (connectivity.isDeviceInOfflineMode()) {
                    log.w("Device is offline, not bringing packet loop back for now")
                    loop = config to null
                } else {
                    log.w("Device is online, bringing packet loop back")
                    loop = createLoop(config)
                    startSupportingServices(config)
                }
            }
        }
    }

    suspend fun stop() {
        log.v("Requested to stop packet loop")
        loop?.let {
            loop = null
            val (_, thread) = it
            thread?.interrupt()
//            log.w("Waiting after stopping packet loop as a workaround")
//            delay(4000)
        }
    }

    fun getStatus() = (loop?.second as? PacketLoopForPlusDoh)?.gatewayId ?:
                        (loop?.second as? PacketLoopForPlus)?.gatewayId

}

private class PacketLoopConfig(
    val usePlusMode: Boolean,
    val dns: Dns,
    val useDoh: Boolean,
    val tunnelConfig: SystemTunnelConfig,
    val privateKey: PrivateKey? = null,
    val gateway: Gateway? = null,
    val useFiltering: Boolean = true
) {

    fun requirePrivateKey(): PrivateKey {
        return if (usePlusMode) privateKey!! else throw BlokadaException("Not Blocka configuration")
    }

    fun requireGateway(): Gateway {
        return if (usePlusMode) gateway!! else throw BlokadaException("Not Blocka configuration")
    }

}