package gs.environment

import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import org.pcap4j.packet.namednumber.UdpPort

/**
 * Contains various utility functions related to connectivity on Android.
 */

fun isConnected(ctx: android.content.Context): Boolean {
    val cm = ctx.getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val activeInfo = cm.activeNetworkInfo ?: return false
    return activeInfo.isConnectedOrConnecting
}

fun isTethering(ctx: android.content.Context, intent: android.content.Intent? = null): Boolean {
    var tethering = false
    if (intent != null) tethering = gs.environment.isTetheringMethod3(intent.extras)
    if (!tethering) tethering = gs.environment.isTetheringMethod1(ctx)
    if (!tethering) tethering = gs.environment.isTetheringMethod2(ctx)
    return tethering
}

fun getDnsServers(ctx: android.content.Context): List<java.net.InetSocketAddress> {
    var servers = if (android.os.Build.VERSION.SDK_INT >= 21) gs.environment.getDnsServersMethod1(ctx) else emptyList()
    if (servers.isEmpty()) servers = gs.environment.getDnsServersMethod2()
    return servers.map { java.net.InetSocketAddress(it, UdpPort.DOMAIN.valueAsInt()) }
}

fun isWifi(ctx: android.content.Context): Boolean {
    val wm = ctx.applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as WifiManager
    return when {
        !wm.isWifiEnabled -> false
        wm.connectionInfo?.networkId ?: -1 != -1 -> true
        else -> false
    }
}

fun hasIpV6Servers(dnsServers: Collection<java.net.InetAddress>): Boolean {
    return dnsServers.any { it is java.net.Inet6Address }
}

private fun isTetheringMethod1(ctx: android.content.Context): Boolean {
    val wm = ctx.applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as WifiManager
    return try {
        val m = wm.javaClass.getMethod("isWifiApEnabled")
        m.isAccessible = true
        val wifiApEnabled = m.invoke(wm) as Boolean?
        wifiApEnabled ?: false
    } catch (e: Exception) {
        false
    }
}

private fun isTetheringMethod2(ctx: android.content.Context): Boolean {
    val wm = ctx.applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as WifiManager
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

private fun isTetheringMethod3(bundle: android.os.Bundle): Boolean {
    val activeTetheringInterface = bundle.getStringArrayList("activeArray")?.toString()
    return activeTetheringInterface?.contains("wlan", true) ?: false
}

@android.annotation.TargetApi(21)
private fun getDnsServersMethod1(ctx: android.content.Context): List<java.net.InetAddress> {
    val cm = ctx.getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val servers = mutableListOf<java.net.InetAddress>()

    val activeInfo = cm.activeNetworkInfo ?: return servers

    for (network in cm.allNetworks) {
        val info = cm.getNetworkInfo(network) ?: continue
        if (!info.isConnected || info.type != activeInfo.type || info.subtype != activeInfo.subtype)
            continue

        servers.addAll(cm.getLinkProperties(network).dnsServers)
    }
    return servers
}

private fun getDnsServersMethod2(): List<java.net.InetAddress> {
    val servers = mutableListOf<java.net.InetAddress>()
    try {
        val SystemProperties = Class.forName("android.os.SystemProperties")
        val method = SystemProperties.getMethod("get", *arrayOf<Class<*>>(String::class.java))
        for (name in arrayOf("net.dns1", "net.dns2", "net.dns3", "net.dns4")) {
            val value = method.invoke(null, name) as String? ?: continue
            if (value.isNotBlank()) servers.add(java.net.InetAddress.getByName(value))
        }
    } catch (e: Exception) {}
    return servers
}
