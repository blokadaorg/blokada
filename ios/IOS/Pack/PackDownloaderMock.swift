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
        // Create destination URL
        self.log.v("Mock download for \(url)")
        return ok(())
    }

    func hasDownloaded(url: Url) -> Bool {
        return true
    }

    func remove(url: Url) {

    }
}
