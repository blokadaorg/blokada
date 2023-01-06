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
import model.NetworkDescriptor
import ui.utils.cause
import utils.Logger
import java.net.InetAddress

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

    var onConnectedBack = {}
    var onConnectivityChanged = { isConnected: Boolean -> }
    var onNetworkAvailable = { network: NetworkDescriptor -> }
    var onActiveNetworkChanged = { network: NetworkDescriptor -> }
    var onPrivateDnsChanged = { privateDns: String? -> }

    var pingToCheckNetwork = false
        @Synchronized set
        @Synchronized get

    var privateDns: String? = null
        @Synchronized set
        @Synchronized get

    // Hold on to data we get from the async callbacks, as per docs mixing them with sync calls is not ok
    private val networkDescriptors = mutableMapOf<NetworkHandle, NetworkDescriptor>()
    private val networkLinks = mutableMapOf<NetworkHandle, LinkProperties>()

    private var defaultRouteNetwork: NetworkHandle? = null
    private var lastSeenRouteNetwork: NetworkHandle? = null

    // The network reported to the outside. Can be "fallback" which means "apply fallback configuration"
    private var activeNetwork = NetworkDescriptor.fallback()

    private val systemCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            scope.launch {
                val descriptor = describeNetwork(network, caps)
                if (descriptor != null) onNetworkAvailable(descriptor) // Announce for the UI to list it
                announceActiveNetwork()
            }
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            scope.launch {
                markDefaultRoute(network, linkProperties)
                announceActiveNetwork()
            }
        }

        override fun onLost(network: Network) {
            scope.launch {
                cleanupLostNetwork(network)
                announceActiveNetwork()
            }
        }
    }

    // Tries to get network name and type. Getting the name is quite unreliable.
    @SuppressLint("MissingPermission")
    private fun NetworkDescriptor.Companion.fromNetwork(network: Network, cap: NetworkCapabilities): NetworkDescriptor {
        return when {
            cap.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                try {
                    // This assumes there is only one active cellular network at a time
                    val id = SubscriptionManager.getDefaultDataSubscriptionId()
                    cell(simManager.getActiveSubscriptionInfo(id)?.carrierName?.toString())
                } catch (ex: Exception) {
                    // Probably no permissions, just identify network type
                    cell(null)
                }
            }
            cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> {
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

                wifi(name)
            }
            else -> fallback()
        }
    }

    // Ensures we keep the best description of given network we can have.
    private fun describeNetwork(network: Network, cap: NetworkCapabilities): NetworkDescriptor? {
        val existing = networkDescriptors[network.networkHandle]
        return try {
            val descriptor = NetworkDescriptor.fromNetwork(network, cap)
            if (existing == null || existing.isFallback() || existing.name == null) {
                // The new descriptor can't be worse, use it instead
                networkDescriptors[network.networkHandle] = descriptor
                descriptor
            } else if (descriptor.name != null) {
                // Maybe this name is more up to date
                networkDescriptors[network.networkHandle] = descriptor
                descriptor
            } else null
        } catch (ex: Exception) {
            if (existing == null) {
                log.w("Could not describe network, using fallback".cause(ex))
                networkDescriptors[network.networkHandle] = NetworkDescriptor.fallback()
            }
            null
        }
    }

    private fun markDefaultRoute(network: Network, link: LinkProperties) {
        networkLinks[network.networkHandle] = link

        // Assume that default route marks the currently preferred (system default) route
        val default = link.routes.any { it.isDefaultRoute }

        if (default && defaultRouteNetwork != network.networkHandle) {
            log.v("New default route through network: ${network.networkHandle}")
            defaultRouteNetwork = network.networkHandle
            onConnectivityChanged(true)
        }

        checkPrivateDns(link)
    }

    private fun checkPrivateDns(link: LinkProperties) {
        when {
            Build.VERSION.SDK_INT < 28 -> {
                log.w("privateDNS unsupported on this Android version")
            }
            link.isPrivateDnsActive -> {
                privateDns = link.privateDnsServerName
                onPrivateDnsChanged(link.privateDnsServerName)
            }
            else -> {
                networkLinks.values.firstOrNull { it.isPrivateDnsActive }?.let {
                    privateDns = it.privateDnsServerName
                    log.w("privateDNS active for ${it.interfaceName}: $privateDns (skipped default network)")
                    onPrivateDnsChanged(it.privateDnsServerName)
                } ?: run {
                    privateDns = null
                    log.w("privateDNS not active")
                    onPrivateDnsChanged(null)
                }
            }
        }
    }

    private fun cleanupLostNetwork(network: Network) {
        val descriptor = networkDescriptors[network.networkHandle]
        log.v("Network lost: ${network.networkHandle} = $descriptor")

        networkDescriptors.remove(network.networkHandle)
        networkLinks.remove(network.networkHandle)

        if (network.networkHandle == defaultRouteNetwork) {
            defaultRouteNetwork = null
        }
    }

    private fun announceActiveNetwork() {
        val descriptor = networkDescriptors[defaultRouteNetwork]

        when {
            doze.isDoze() -> {
                val fallback = NetworkDescriptor.fallback()
                activeNetwork = fallback
                lastSeenRouteNetwork = null
                log.v("Doze active")

                onConnectivityChanged(false)
                onActiveNetworkChanged(fallback)
            }
            defaultRouteNetwork == lastSeenRouteNetwork -> {
                // Ignore, we have already processed this network
            }
            defaultRouteNetwork == null -> {
                val fallback = NetworkDescriptor.fallback()
                activeNetwork = fallback
                lastSeenRouteNetwork = defaultRouteNetwork
                log.v("Lost default network, no connectivity")

                onConnectivityChanged(false)
                onActiveNetworkChanged(fallback)
            }
            descriptor == null -> {
                // Ignore, we are waiting to receive network capabilities callback
            }
            else -> {
                // This is the normal case of switching networks
                activeNetwork = descriptor
                lastSeenRouteNetwork = defaultRouteNetwork
                log.v("Network is now default: $defaultRouteNetwork = $descriptor")

                onConnectivityChanged(true)
                onConnectedBack()
                onNetworkAvailable(descriptor) // Announce again just in case we haven't yet (shouldn't happen)
                onActiveNetworkChanged(descriptor)
            }
        }
    }

    fun setup() {
        doze.onDozeChanged = { doze ->
            announceActiveNetwork()
        }
        rescan()
    }

    fun rescan() {
        // We can't use the default network callback because it returns ourselves (the VPN network).
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        try { manager.unregisterNetworkCallback(systemCallback) } catch (ex: Exception) {}
        manager.registerNetworkCallback(request, systemCallback)
    }

    fun getActiveNetwork(): NetworkDescriptor {
        return activeNetwork
    }

    fun getActiveNetworkDns(): List<InetAddress> {
        return defaultRouteNetwork?.let { active ->
            networkLinks[active]?.dnsServers?.filterIsInstance<java.net.Inet4Address>() ?: emptyList()
        } ?: emptyList()
    }

    fun isDeviceInOfflineMode(): Boolean {
        return when {
            defaultRouteNetwork != null -> false
            isConnectedOldApi() -> false
            //doze.isDoze() -> true
            else -> true
        }
    }

    private fun isConnectedOldApi(): Boolean {
        val activeInfo = manager.activeNetworkInfo ?: return false
        return activeInfo.isConnected
    }

    private fun LinkProperties.usesPrivateDns(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isPrivateDnsActive else false
    }

}

private typealias NetworkHandle = Long