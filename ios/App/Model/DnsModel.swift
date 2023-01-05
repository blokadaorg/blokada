//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

struct Dns: Codable {
    let ips: [String]
    let port: Int
    let name: String
    let path: String
    let label: String
    let plusIps: [String]?
}


extension Dns: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
    }
}

extension Dns: Equatable {
    static func == (lhs: Dns, rhs: Dns) -> Bool {
        lhs.label == rhs.label
    }
}

extension Dns {

    func persist() {
        if let dnsString = self.toJson() {
            UserDefaults.standard.set(dnsString, forKey: "dns")
        } else {
            BlockaLogger.w("Dns", "Could not convert dns to json")
        }
    }

    static func load() -> Dns {
        let result = UserDefaults.standard.string(forKey: "dns")
        guard let stringData = result else {
            return Dns.defaultDns()
        }

        let jsonData = stringData.data(using: .utf8)
        guard let json = jsonData else {
            BlockaLogger.e("Dns", "Failed getting dns json")
            return Dns.defaultDns()
        }

        do {
            return try blockaDecoder.decode(Dns.self, from: json)
        } catch {
            BlockaLogger.e("Dns", "Failed decoding dns json".cause(error))
            return Dns.defaultDns()
        }
    }

    static var blocka = Dns(ips: ["193.180.80.1", "193.180.80.2"], port: 443, name: "dns.blokada.org", path: "dns-query", label: "Blokada DNS (beta)", plusIps: ["193.180.80.100", "193.180.80.101"])

    static var hardcoded = [
        //Dns(ips: ["176.103.130.130", "176.103.130.131", "2a00:5a60::ad1:0ff", "2a00:5a60::ad2:0ff"], port: 443, name: "dns.adguard.com", path: "dns-query", label: "Adguard"),
        //Dns(ips: ["185.228.168.9", "185.228.169.9", "2a0d:2a00:1::2", "2a0d:2a00:2::2"], port: 443, name: "doh.cleanbrowsing.org", path: "doh/security-filter", label: "CleanBrowsing: Security filter"),
        //Dns(ips: ["185.228.168.10", "185.228.169.11", "2a0d:2a00:1::1", "2a0d:2a00:2::1"], port: 443, name: "doh.cleanbrowsing.org", path: "doh/adult-filter", label: "CleanBrowsing: Adult filter"),
        blocka,
        Dns(ips: ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"], port: 443, name: "cloudflare-dns.com", path: "dns-query", label: "Cloudflare", plusIps: nil),
        // Turns out those two are not DoH
        //Dns(ips: ["1.1.1.2", "1.0.0.2", "2606:4700:4700::1112", "2606:4700:4700::1002"], port: 443, name: "cloudflare-dns.com", path: "dns-query", label: "Cloudflare: malware blocking"),
        //Dns(ips: ["1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003"], port: 443, name: "cloudflare-dns.com", path: "dns-query", label: "Cloudflare: malware & adult blocking"),
        // TODO #927: require DoH according to RFC 8484 support
        // Dns(ips: ["185.95.218.42", "185.95.218.43", "2a05:fc84::42", "2a05:fc84::43"], port: 443, name: "dns.digitale-gesellschaft.ch", path: "dns-query", label: "Digitale Gesellschaft (Switzerland)", plusIps: nil),
        Dns(ips: ["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"], port: 443, name: "dns.google", path: "resolve", label: "Google", plusIps: nil),
    ]

    static func defaultDns() -> Dns {
        return hardcoded.first { $0.label == "Cloudflare" }!
    }

}
