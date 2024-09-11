//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
// "2024-09-10T14:23:22.610043"
let blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
let blockaDateFormatNoNanos = "yyyy-MM-dd'T'HH:mm:ssZ"

let userDateFormatSimple = "dMMMMyyyy"
let userDateFormatFull = "yyyyMMd jms"
let userDateFormatChat = "E., MMd, jms"

let blockaEncoder = initJsonEncoder()
let blockaDecoder = initJsonDecoder()
let blockaDateFormatter = initDateFormatter()

func initDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = blockaDateFormat
    return dateFormatter
}

func initJsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let dateFormatter = blockaDateFormatter
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    return decoder
}

func initJsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    let dateFormatter = blockaDateFormatter
    encoder.dateEncodingStrategy = .formatted(dateFormatter)
    return encoder
}

extension Encodable {
    func toJson() -> String? {
        do {
            let jsonData = try blockaEncoder.encode(self)
            let jsonString = String(data: jsonData, encoding: .utf8)
            guard let json = jsonString else {
                BlockaLogger.e("JSON", "jsonString was nil")
                return nil
            }
            return json
        } catch {
            BlockaLogger.e("JSON", "Failed encoding to json".cause(error))
            return nil
        }
    }

    func toJsonData() -> Data? {
        do {
            return try blockaEncoder.encode(self)
        } catch {
            return nil
        }
    }
}
