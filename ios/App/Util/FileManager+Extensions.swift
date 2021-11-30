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

extension FileManager {
    func merge(files: [URL], to destination: URL, chunkSize: Int = 1000000) throws {
        try FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        let writer = try FileHandle(forWritingTo: destination)
        try files.forEach({ partLocation in
              let reader = try FileHandle(forReadingFrom: partLocation)
              var data = reader.readData(ofLength: chunkSize)
              while data.count > 0 {
                    writer.write(data)
                    data = reader.readData(ofLength: chunkSize)
              }
              reader.closeFile()
        })
        writer.closeFile()
    }
}
