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
