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
