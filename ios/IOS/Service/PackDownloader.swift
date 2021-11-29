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

class PackDownloader {

    private let log = Logger("Pack")

    func download(url: Url, ok: @escaping Ok<Void>, fail: @escaping Fail) {
        let destinationUrl = getDestination(url)

        let count = api_hostlist(NetworkService.shared.httpClient, url, destinationUrl.path)
        if count == 0 {
            remove(url: url)
            return fail("Could not fetch domains for \(url)")
        } else {
            self.log.v("Found \(count) domains for \(url)")
            return ok(())
        }
    }

    func hasDownloaded(url: Url) -> Bool {
        let destinationUrl = getDestination(url)
        return FileManager.default.fileExists(atPath: destinationUrl.path)
    }

    func remove(url: Url) {
        let destinationUrl = getDestination(url)
        try? FileManager.default.removeItem(at: destinationUrl)
    }

    private func getDestination(_ url: Url) -> URL {
        return FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("\(url)".toBase64())
    }
}
