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

import android.annotation.SuppressLint
import android.content.Context
import android.net.*
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.SubscriptionManager
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.*
import ui.utils.cause
import utils.Logger
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket

object ConnectivityService {

    private val log = Logger("Connectivity")
    private val context = ContextService
    private val doze = DozeService
    private val scope = GlobalScope

    private val manager by lazy {
        context.requireAppContext().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private val wifiManager by lazy {
        context.requireAppContext().getSystemService(Context.WIFI_SERVICE) as WifiManager
    }

    private val simManager by lazy {
        context.requireAppContext().getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
    }

    var onConnectivityChanged = { isConnected: Boolean -> }
    var onNetworkAvailable = { network: NetworkDescriptor -> }
    var onActiveNetworkChanged = { network: NetworkDescriptor -> }

    private var networks = mutableMapOf<NetworkDescriptor, Network>()
    private var networksLost = emptyList<NetworkHandle>()
    private var activeNetwork: Pair<NetworkDescriptor, Network?> = NetworkDescriptor.fallback() to null

    private val systemCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            //log.v("Network status changed: ${network.networkHandle}")
            handleNetworkChange(network)
        }

        override fun onLost(network: Network) {
            //log.v("Network status lost: ${network.networkHandle}")
            handleNetworkChange(network)
        }
    }

    fun setup() {
        doze.onDozeChanged = { doze ->
            decideActiveNetwork()
        }
        rescan()
    }

    fun rescan() {
        val request = NetworkRequest.Builder().build()
        try { manager.unregisterNetworkCallback(systemCallback) } catch (ex: Exception) {}
        manager.registerNetworkCallback(request, systemCallback)
    }

    private fun handleNetworkChange(network: Network) {
        scope.launch {
            NetworkDescriptor.fromNetwork(network)?.let { (descriptor, hasConnectivity) ->
                // Would be nicer to have a reversed map, but it's late and I'm tired
                val existing = networks.filterValues { it.networkHandle == network.networkHandle }.keys.firstOrNull()
                existing?.let { networks.remove(it) }
                networks[descriptor] = network

                if (hasConnectivity) {
                    log.v("Network up: ${network.networkHandle}, $descriptor")
                    networksLost -= network.networkHandle
                    decideActiveNetwork(becameAvailable = network.networkHandle)
                } else {
                    log.v("Network down: ${network.networkHandle}, $descriptor")
                    networksLost += network.networkHandle
                    decideActiveNetwork()
                }
            }
        }
    }

    private fun decideActiveNetwork(becameAvailable: NetworkHandle? = null) {
        val available = networks.filterValues { it.networkHandle !in networksLost }.entries
        log.v("Available networks: $available")
        val hasConnectivity = when (available.size) {
            0 -> {
                activeNetwork = NetworkDescriptor.fallback() to null
                false
            }
            1 -> {
                activeNetwork = available.first().toPair()
                !doze.isDoze()
            }
            else -> {
                val subjectNetwork = available.firstOrNull { it.value.networkHandle == becameAvailable }
                val wifiNetworks = available.filter { it.key.type == NetworkType.WIFI }
                when {
                    wifiNetworks.isEmpty() -> {
                        subjectNetwork?.let { network ->
                            // Use the network that just became available
                            activeNetwork = network.toPair()
                        } ?: run {
                            // Use a network that is still reported as available. This is displeasing.
                            activeNetwork = available.last().toPair()
                            log.w("Guessing which network to use: ${activeNetwork.first}")
                        }
                    }
                    subjectNetwork?.key?.type == NetworkType.WIFI -> activeNetwork = subjectNetwork.toPair()
                    else -> {
                        activeNetwork = wifiNetworks.last().toPair()
                        log.w("Guessing which wifi network to use: ${activeNetwork.first}")
                    }
                }
                !doze.isDoze()
            }
        }

        onConnectivityChanged(hasConnectivity)
        onNetworkAvailable(activeNetwork.first)
        onActiveNetworkChanged(activeNetwork.first)
    }

    fun getActiveNetwork(): NetworkDescriptor {
        return activeNetwork.first
    }

    fun getActiveNetworkDns(): List<InetAddress> {
        return manager.getLinkProperties(activeNetwork.second)
            ?.dnsServers?.filterIsInstance<java.net.Inet4Address>() ?: emptyList()
    }

    fun isDeviceInOfflineMode(): Boolean {
        return when {
            doze.isDoze() -> true
            networks.filterValues { it.networkHandle !in networksLost }.isNotEmpty() -> false
            isConnectedOldApi() -> false
            else -> true
        }
    }

    private fun isConnectedOldApi(): Boolean {
        val activeInfo = manager.activeNetworkInfo ?: return false
        return activeInfo.isConnected
    }

    @SuppressLint("MissingPermission")
    private fun NetworkDescriptor.Companion.fromNetwork(network: Network): Pair<NetworkDescriptor, HasConnectivity>? {
        return try {
            val cap = manager.getNetworkCapabilities(network)
            when {
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false -> {
                    // Ignore VPN network since it's us
                    null
                }
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ?: false -> {
                    // This assumes there is only one active cellular network at a time
                    val hasConnectivity = cap?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false
                    try {
                        val id = SubscriptionManager.getDefaultDataSubscriptionId()
                        cell(simManager.getActiveSubscriptionInfo(id)?.carrierName?.toString()) to hasConnectivity
                    } catch (ex: Exception) {
                        // Probably no permissions, just identify network type
                        cell(null) to hasConnectivity
                    }
                }
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ?: false -> {
                    // This assumes there is only one active WiFi network at a time
                    var name: String? = wifiManager.connectionInfo.ssid.trim('"')
                    if (name == WifiManager.UNKNOWN_SSID) {
                        name = null
                    } // No perms in bg, we'll try next time

                    if (name == null) {
                        // Of course, this being Android, there are some weird cases in the wild
                        // where we get null despite having the perms. Try to use a fallback.
                        name = wifiManager.connectionInfo.bssid?.trim('"')
                        if (name == "02:00:00:00:00:00") name = null // No perms (according to docs)
                    }

                    if (name == null) {
                        log.v("Wifi network fallback name detection returned null")
                    }

                    // Android reporting is extremely unclear on the flags reported for wifi vs mobile
                    var hasConnectivity = cap?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false

                    // Additional actual connectivity check because we can't trust it
                    if (hasConnectivity) {
                        log.v("Making connectivity check")
                        val socket = Socket()
                        socket.soTimeout = 3000
                        hasConnectivity = try {
                            // blokada.org
                            socket.connect(InetSocketAddress("104.21.11.200", 80), 3000)
                            true
                        } catch (ex: Exception) {
                            log.w("Wifi network reported to be online, but connectivity check failed")
                            false
                        }
                    }
                    wifi(name) to hasConnectivity
                }
                else -> {
                    val hasConnectivity = cap?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false
                    val known = networks.filterValues { it.networkHandle == network.networkHandle }.entries.firstOrNull()?.key
                    (known ?: fallback()) to hasConnectivity
                }
            }
        } catch (ex: Exception) {
            log.w("Could not recognize network".cause(ex))
            return fallback() to true // Assume it has connectivity
        }
    }

    private fun LinkProperties.usesPrivateDns(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isPrivateDnsActive else false
    }

}

private typealias HasConnectivity = Boolean
private typealias NetworkHandle = Long