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

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET
import android.net.NetworkRequest
import utils.Logger

object ConnectivityService {

    private val log = Logger("Connectivity")
    private val context = ContextService
    private val doze = DozeService
    private val manager by lazy {
        context.requireAppContext().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private var availableNetworks = emptyList<NetworkId>()
        set(value) {
            field = value
            hasAvailableNetwork = field.isNotEmpty()
        }

    private var hasAvailableNetwork = false

    var onConnectivityChanged = { isConnected: Boolean -> }

    fun setup() {
        val network = NetworkRequest.Builder().addCapability(NET_CAPABILITY_INTERNET).build()
        manager.registerNetworkCallback(network, object : ConnectivityManager.NetworkCallback() {
            override fun onLost(network: Network) {
                log.w("Network unavailable: ${network.networkHandle}")
                availableNetworks -= network.networkHandle
                if (!hasAvailableNetwork) onConnectivityChanged(false)
            }

            override fun onAvailable(network: Network) {
                log.w("Network available: $network")
                availableNetworks += network.networkHandle
                val canConnect = !doze.isDoze()
                onConnectivityChanged(canConnect)
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

    fun isDeviceInOfflineMode(): Boolean {
        return (!hasAvailableNetwork && !isConnectedOldApi()) || doze.isDoze()
    }

    private fun isConnectedOldApi(): Boolean {
        val activeInfo = manager.activeNetworkInfo ?: return false
        return activeInfo.isConnected
    }

}

private typealias NetworkId = Long