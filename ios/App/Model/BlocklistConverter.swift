//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

func convertBlocklists(blocklists: [Blocklist]) -> [MappedBlocklist] {
    return blocklists.compactMap { blocklist in
        let mapped = getPackIdAndConfig(id: blocklist.id, pathName: blocklist.name)
        guard mapped != nil else {
            //BlockaLogger.w("Blocklist", "Could not recognize blocklist for path: \(blocklist.name)")
            return nil
        }

        return mapped
    }
}

func getPackIdAndConfig(id: String, pathName: String) -> MappedBlocklist? {
    var packId: String? = nil
    var packConfig: String? = nil

    let nsrange = NSRange(pathName.startIndex ..< pathName.endIndex, in: pathName)
    namePattern.enumerateMatches(in: pathName, options: [], range: nsrange) { (match, _, stop) in
        guard let match = match else { return }

        if match.numberOfRanges == 3,
           let firstCaptureRange = Range(match.range(at: 1), in: pathName),
           let secondCaptureRange = Range(match.range(at: 2), in: pathName)
        {
            packId = String(pathName[firstCaptureRange])
            packConfig = String(pathName[secondCaptureRange]).capitalizingFirstLetter()
        }
    }

    if packId != nil && packConfig != nil {
        return MappedBlocklist(id: id, packId: packId!, packConfig: packConfig!)
    } else {
        return nil
    }
}

private let namePattern = try! NSRegularExpression(pattern: "mirror\\/v5\\/(\\w+)\\/([a-zA-Z0-9_ ]+)\\/hosts\\.txt")
