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

extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

extension Int {

    var minutesSeconds: String {
        if self <= 0 {
            return "00:00"
        } else {
            return String(format: "%02d:%02d", self / 60, self % 60)
        }
    }

    var compact: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000.0)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000.0)
        } else {
            return String(self)
        }
    }

}

extension UInt64 {

    var upTo99: String {
        if self > 99 {
            return "99+"
        } else {
            return String(self)
        }
    }

    var compact: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000.0)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000.0)
        } else {
            return String(self)
        }
    }

    var veryCompact: String {
        if self >= 1_000_000 {
            return String(format: "%dM", Int((Double(self) / 1_000_000.0).rounded()))
        } else if self >= 1_000 {
            return String(format: "%dK", Int((Double(self) / 1_000.0).rounded()))
        } else {
            return String(self)
        }
    }

}
