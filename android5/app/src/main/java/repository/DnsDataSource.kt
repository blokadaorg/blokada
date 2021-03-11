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

package repository

import model.Dns
import model.DnsId

object DnsDataSource {

    val network = Dns.plaintextDns(
        id = "network",
        ips = listOf(),
        label = "Network DNS"
    )

    val blocka = Dns(
        id = "blocka2",
        ips = listOf("193.180.80.1", "193.180.80.2"),
        plusIps = listOf("193.180.80.100", "193.180.80.101"),
        label = "Blokada DNS",
        port = 443,
        name = "dns.blokada.org",
        path = "dns-query",
        canUseInCleartext = false
    )

    val cloudflare = Dns(
        id = "cloudflare",
        ips = listOf("1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"),
        port = 443,
        name = "cloudflare-dns.com",
        path = "dns-query",
        label = "Cloudflare"
    )

    fun getDns() = listOf(
        blocka,
        Dns.plaintextDns(
            id = "adguard",
            ips = listOf("94.140.14.14", "94.140.15.15", "2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"),
            label = "AdGuard"
        ),
        Dns.plaintextDns(
            id = "adguard_family",
            ips = listOf("176.103.130.132", "176.103.130.134"),
            label = "AdGuard: family"
        ),
        Dns.plaintextDns(
            id = "alternate",
            ips = listOf("76.76.19.19", "76.223.122.150", "2001:4801:7825:103:be76:4eff:fe10:2e49", "2001:4800:780e:510:a8cf:392e:ff04:8982"),
            label = "Alternate DNS"
        ),
        cloudflare,
        Dns.plaintextDns(
            id = "cloudflare.malware",
            ips = listOf("1.1.1.2", "1.0.0.2", "2606:4700:4700::1112", "2606:4700:4700::1002"),
            label = "Cloudflare: malware blocking"
        ),
        Dns.plaintextDns(
            id = "cloudflare.adult",
            ips = listOf("1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003"),
            label = "Cloudflare: malware & adult blocking"
        ),
        Dns.plaintextDns(
            id = "digitalcourage",
            ips = listOf("46.182.19.48", "46.182.19.48"),
            label = "Digitalcourage"
        ),
        Dns.plaintextDns(
            id = "dismail",
            ips = listOf("80.241.218.68", "159.69.114.157", "2a02:c205:3001:4558::1", "2a01:4f8:c17:739a::2"),
            label = "Dismail",
            region = "europe"
        ),
        Dns.plaintextDns(
            id = "dnswatch",
            ips = listOf("84.200.69.80", "84.200.70.40"),
            label = "DNS.Watch"
        ),
//        Dns.plaintextDns(
//            id = "freenom",
//            ips = listOf("80.80.80.80", "80.80.81.81"),
//            label = "Freenom"
//        ),
        Dns.plaintextDns(
            id = "fdn",
            ips = listOf("80.67.169.12", "80.67.169.40"),
            label = "French Data Network"
        ),
        Dns(
            id = "digitalegesellschaft",
            ips = listOf("185.95.218.42", "185.95.218.43", "2a05:fc84::42", "2a05:fc84::43"),
            port = 443,
            name = "dns.digitale-gesellschaft.ch",
            path = "dns-query",
            label = "Digitale Gesellschaft (Switzerland)",
            canUseInCleartext = false,
            region = "europe"
        ),
        Dns(
            id = "google",
            ips = listOf("8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"),
            port = 443,
            name = "dns.google",
            path = "resolve",
            label = "Google"
        ),
        Dns.plaintextDns(
            id = "opendns",
            ips = listOf("208.67.222.222", "208.67.220.220"),
            label = "Open DNS"
        ),
        Dns.plaintextDns(
            id = "opendns_family",
            ips = listOf("208.67.220.123", "208.67.222.123"),
            label = "Open DNS: family"
        ),
        Dns.plaintextDns(
            id = "quad9",
            ips = listOf("9.9.9.9", "149.112.112.112"),
            label = "Quad9"
        ),
        Dns.plaintextDns(
            id = "quad101",
            ips = listOf("101.101.101.101", "101.102.103.104"),
            label = "Quad 101"
        ),
        Dns.plaintextDns(
            id = "uncensored",
            ips = listOf("91.239.100.100", "89.233.43.71"),
            label = "Uncensored DNS"
        ),
        Dns.plaintextDns(
            id = "verisign",
            ips = listOf("64.6.64.6", "64.6.65.6"),
            label = "Verisign Public DNS"
        )
    )

    // All special cases and removed legacy needs to be handled here to not cause crashes when migrating
    fun byId(dnsId: DnsId) = when(dnsId) {
        network.id -> network
        else -> getDns().firstOrNull { it.id == dnsId } ?: cloudflare // Fallback for previously selected removed DNS
    }
}