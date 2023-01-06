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

import model.*
import newengine.BlockaDnsService
import org.pcap4j.packet.namednumber.UdpPort
import repository.DnsDataSource
import service.ConnectivityService
import utils.Logger
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

object DnsMapperService {

    private val log = Logger("DnsMapper")

    private var servers = emptyList<InetAddress>()
    private var useProxyDns = false

    fun setDns(dns: Dns, doh: Boolean, plusMode: Boolean = false) {
        log.v("Using DNS configuration [DoH/PlusMode: $doh/$plusMode]: $dns")

        servers = decideDns(dns, plusMode)

        if (servers.isEmpty()) throw BlokadaException("No DNS servers found")
        else log.v("Using DNS: $servers")

        useProxyDns = false
        if (dns.isDnsOverHttps() && doh) {
            log.v("Will use DNS over HTTPS")
            useProxyDns = true
        }
    }

    fun count() = servers.size

    fun externalForIndex(index: Int): InetAddress {
        return if (useProxyDns) proxyDnsIp else servers[index]
    }

    fun externalToInternal(address: InetAddress): InetAddress? {
        val src = dnsProxyDst4.copyOf()
        return if (useProxyDns) {
            src[3] = 1.toByte()
            Inet4Address.getByAddress(src)
        } else {
            val dst = servers.firstOrNull { it == address }
            if (dst != null) {
                val index = servers.indexOf(dst)
                src[3] = (index + 1).toByte()
                Inet4Address.getByAddress(src)
            } else null
        }
    }

    fun internalToExternal(address: InetAddress): InetAddress {
        return when {
            servers.isEmpty() -> address
            else -> try {
                // Last octet of DNS server IP corresponds to its index
                val index = address.address.last() - 1
                servers[index]
            } catch (e: Exception) {
                address
            }
        }
    }

    fun dstDnsPort(): UdpPort {
        return if (useProxyDns) proxyDnsPort else UdpPort.DOMAIN
    }

    val proxyDnsIpBytes = byteArrayOf(127, 0, 0, 1)
    val proxyDnsIp = Inet4Address.getByAddress(proxyDnsIpBytes)
    val proxyDnsPort = UdpPort(BlockaDnsService.PROXY_PORT, "blocka-doh-proxy")

}

fun decideDns(dns: Dns, plusMode: Boolean): List<InetAddress> {
    return when {
        dns.id == DnsDataSource.network.id -> {
            ConnectivityService.getActiveNetworkDns()
        }
        plusMode && dns.plusIps != null -> dns.plusIps.ipv4().map { Inet4Address.getByName(it) }
        else -> dns.ips.ipv4().map { Inet4Address.getByName(it) }
    }
}

// A TEST-NET IP range from RFC5735
private const val dnsProxyDst4String = "203.0.113.0"
internal val dnsProxyDst4 = Inet4Address.getByName(dnsProxyDst4String).address!!

// A special test subnet from RFC3849
private const val dnsProxyDst6String = "2001:DB8::"
internal val dnsProxyDst6 = Inet6Address.getByName(dnsProxyDst6String).address!!

