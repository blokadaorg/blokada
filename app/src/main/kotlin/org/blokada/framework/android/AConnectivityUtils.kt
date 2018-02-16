package org.blokada.framework.android

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import com.github.salomonbrys.kodein.instance
import java.net.Inet6Address
import java.net.InetAddress

internal fun isConnected(ctx: Context): Boolean {
    val cm = ctx.di().instance<ConnectivityManager>()
    val activeInfo = cm.activeNetworkInfo ?: return false
    return activeInfo.isConnectedOrConnecting
}

internal fun isTethering(ctx: Context, intent: Intent? = null): Boolean {
    var tethering = false
    if (intent != null) tethering = isTetheringMethod3(intent.extras)
    if (!tethering) tethering = isTetheringMethod1(ctx)
    if (!tethering) tethering = isTetheringMethod2(ctx)
    return tethering
}

internal fun getDnsServers(ctx: Context): List<InetAddress> {
    var servers = if (Build.VERSION.SDK_INT >= 21) getDnsServersMethod1(ctx) else emptyList()
    if (servers.isEmpty()) servers = getDnsServersMethod2()
    return servers
}

internal fun hasIpV6Servers(dnsServers: Collection<InetAddress>): Boolean {
    return dnsServers.any { it is Inet6Address }
}

private fun isTetheringMethod1(ctx: Context): Boolean {
    val wm: WifiManager = ctx.di().instance()
    return try {
        val m = wm.javaClass.getMethod("isWifiApEnabled")
        m.isAccessible = true
        val wifiApEnabled = m.invoke(wm) as Boolean?
        wifiApEnabled ?: false
    } catch (e: Exception) {
        false
    }
}

private fun isTetheringMethod2(ctx: Context): Boolean {
    val wm: WifiManager = ctx.di().instance()
    return try {
        val m = wm.javaClass.getMethod("getWifiApState")
        m.isAccessible = true
        val actualState = m.invoke(wm) as Int
        /**
         * AP_STATE_DISABLING = 10;
         * AP_STATE_DISABLED = 11;
         * AP_STATE_ENABLING = 12;
         * AP_STATE_ENABLED = 13;
         * AP_STATE_FAILED = 14;
         */
        actualState == 13
    } catch (e: Exception) {
        false
    }
}

private fun isTetheringMethod3(bundle: Bundle): Boolean {
    val activeTetheringInterface = bundle.getStringArrayList("activeArray")?.toString()
    return activeTetheringInterface?.contains("wlan", true) ?: false
}

@android.annotation.TargetApi(21)
private fun getDnsServersMethod1(ctx: Context): List<InetAddress> {
    val cm: ConnectivityManager = ctx.di().instance()
    val servers = mutableListOf<InetAddress>()

    val activeInfo = cm.activeNetworkInfo ?: return servers

    for (network in cm.allNetworks) {
        val info = cm.getNetworkInfo(network) ?: continue
        if (!info.isConnected || info.type != activeInfo.type || info.subtype != activeInfo.subtype)
            continue

        servers.addAll(cm.getLinkProperties(network).dnsServers)
    }
    return servers
}

private fun getDnsServersMethod2(): List<InetAddress> {
    val servers = mutableListOf<InetAddress>()
    try {
        val SystemProperties = Class.forName("android.os.SystemProperties")
        val method = SystemProperties.getMethod("get", *arrayOf<Class<*>>(String::class.java))
        for (name in arrayOf("net.dns1", "net.dns2", "net.dns3", "net.dns4")) {
            val value = method.invoke(null, name) as String? ?: continue
            if (value.isNotBlank()) servers.add(InetAddress.getByName(value))
        }
    } catch (e: Exception) {}
    return servers
}
