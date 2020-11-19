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

package repository

import model.Dns

object DnsDataSource {

    val blocka = Dns(
        id = "blocka",
        ips = listOf("193.180.80.1", "193.180.80.2"),
        plusIps = listOf("193.180.80.100", "193.180.80.101"),
        label = "Blokada DNS (beta)",
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
            ips = listOf("23.253.163.53", "198.101.242.72"),
            label = "Alternate DNS"
        ),
        Dns(
            id = "blahdns.de",
            ips = listOf("159.69.198.101", "2a01:4f8:1c1c:6b4b::1"),
            port = 443,
            name = "doh-de.blahdns.com",
            path = "dns-query",
            label = "Blah DNS (Germany)"
        ),
        Dns(
            id = "blahdns.jp",
            ips = listOf("45.32.55.94", "2001:19f0:7001:3259:5400:02ff:fe71:0bc9"),
            port = 443,
            name = "doh-jp.blahdns.com",
            path = "dns-query",
            label = "Blah DNS (Japan)"
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
            canUseInCleartext = false
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
        Dns(
            id = "opennic.usa",
            ips = listOf("155.138.240.237", "2001:19f0:6401:b3d:5400:2ff:fe5a:fb9f"),
            port = 443,
            name = "ns03.dns.tin-fan.com",
            path = "dns-query",
            label = "OpenNIC: USA"
        ),
        Dns(
            id = "opennic.europe",
            ips = listOf("95.217.16.205", "2a01:4f9:c010:6093::3485"),
            port = 443,
            name = "ns01.dns.tin-fan.com",
            path = "dns-query",
            label = "OpenNIC: Europe"
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
//        Dns.plaintextDns(
//            id = "tenta",
//            ips = listOf("99.192.182.100", "99.192.182.101"),
//            label = "Tenta DNS"
//        ),
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

}