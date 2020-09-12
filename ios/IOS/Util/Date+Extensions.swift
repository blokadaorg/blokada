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

extension Date {

    static var yesterday: Date { return Date().dayBefore }
    static var tomorrow:  Date { return Date().dayAfter }

    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }

    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }

    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }

    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }

    var isLastDayOfMonth: Bool {
        return dayAfter.month != month
    }

    static let formatter = RelativeDateTimeFormatter()

    var relative: String {
        return Date.formatter.localizedString(for: self, relativeTo: Date())
    }

    var human: String {
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = DateFormatter.dateFormat(fromTemplate: userDateFormatFull, options: 0, locale: Locale.current)!
        return dateFormatterGet.string(from: self)
    }

    var humanChat: String {
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = DateFormatter.dateFormat(fromTemplate: userDateFormatChat, options: 0, locale: Locale.current)!
        return dateFormatterGet.string(from: self)
    }
}
