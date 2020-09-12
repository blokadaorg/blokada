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
