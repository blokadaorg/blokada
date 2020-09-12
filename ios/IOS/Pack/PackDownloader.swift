//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
