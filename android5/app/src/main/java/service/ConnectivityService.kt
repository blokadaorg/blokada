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

package service

import android.annotation.SuppressLint
import android.content.Context
import android.net.*
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.SubscriptionManager
import model.*
import ui.utils.cause
import utils.Logger
import java.net.InetAddress

object ConnectivityService {

    private val log = Logger("Connectivity")
    private val context = ContextService
    private val doze = DozeService

    private val manager by lazy {
        context.requireAppContext().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private val wifiManager by lazy {
        context.requireAppContext().getSystemService(Context.WIFI_SERVICE) as WifiManager
    }

    private val simManager by lazy {
        context.requireAppContext().getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
    }

    private var availableNetworks = emptyList<NetworkDescriptor>()
        set(value) {
            field = value
            hasAvailableNetwork = field.isNotEmpty()
        }

    private var networkToHandle = mutableMapOf<NetworkDescriptor, Network>()

    private var hasAvailableNetwork = false

    var activeNetwork: NetworkDescriptor = NetworkDescriptor.fallback()
        set(value) {
            field = value
            onActiveNetworkChanged(value)
        }

    var onConnectivityChanged = { isConnected: Boolean -> }
    var onNetworkAvailable = { network: NetworkDescriptor -> }
    var onActiveNetworkChanged = { network: NetworkDescriptor -> }

    fun setup() {
        manager.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onLost(network: Network) {
                NetworkDescriptor.fromNetwork(network)?.let { descriptor ->
                    log.w("Unavailable network: $descriptor")
                    availableNetworks -= descriptor
                    if (!hasAvailableNetwork) {
                        onConnectivityChanged(false)
                        activeNetwork = NetworkDescriptor.fallback()
                    } else {
                        activeNetwork = availableNetworks.last()
                    }
                }
            }

            override fun onAvailable(network: Network) {
                NetworkDescriptor.fromNetwork(network)?.let { descriptor ->
                    log.w("Network available: $descriptor")

                    if (descriptor.type != NetworkType.FALLBACK)
                        networkToHandle[descriptor] = network

                    availableNetworks += descriptor
                    val canConnect = !doze.isDoze()
                    onConnectivityChanged(canConnect)
                    onNetworkAvailable(descriptor)
                    activeNetwork = descriptor
                }
            }
        })

        doze.onDozeChanged = { doze ->
            if (doze) onConnectivityChanged(false)
            else {
                val canConnect = availableNetworks.isNotEmpty()
                onConnectivityChanged(canConnect)
            }
        }
    }

    fun getActiveNetworkDns(): List<InetAddress> {
        return manager.getLinkProperties(networkToHandle[activeNetwork])
            ?.dnsServers?.filter { it is java.net.Inet4Address } ?: emptyList()
    }

    fun isDeviceInOfflineMode(): Boolean {
        return (!hasAvailableNetwork && !isConnectedOldApi()) || doze.isDoze()
    }

    private fun isConnectedOldApi(): Boolean {
        val activeInfo = manager.activeNetworkInfo ?: return false
        return activeInfo.isConnected
    }

    @SuppressLint("MissingPermission")
    private fun NetworkDescriptor.Companion.fromNetwork(network: Network): NetworkDescriptor? {
        return try {
            val cap = manager.getNetworkCapabilities(network)
            when {
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false -> {
                    // Ignore VPN network since it's us
                    null
                }
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ?: false -> {
                    // This assumes there is only one active WiFi network at a time
                    var name: String? = wifiManager.connectionInfo.ssid.trim('"')
                    if (name == "<unknown ssid>") name = null // No perms in bg, we'll try next time
                    wifi(name)
                }
                cap?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ?: false -> {
                    // This assumes there is only one active cellular network at a time
                    try {
                        val id = SubscriptionManager.getDefaultDataSubscriptionId()
                        cell(simManager.getActiveSubscriptionInfo(id)?.carrierName?.toString())
                    } catch (ex: Exception) {
                        // Probably no permissions, just identify network type
                        cell(null)
                    }
                }
                else -> fallback()
            }
        } catch (ex: Exception) {
            log.w("Could not recognize network".cause(ex))
            return fallback()
        }
    }

    private fun LinkProperties.usesPrivateDns(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isPrivateDnsActive else false
    }

}