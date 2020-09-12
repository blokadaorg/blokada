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

class ActivityItemViewModel: ObservableObject {

    @Published var entry: HistoryEntry
    @Published var whitelisted: Bool
    @Published var blacklisted: Bool

    private var timer: Timer? = nil

    init(entry: HistoryEntry, whitelisted: Bool, blacklisted: Bool) {
        self.entry = entry
        self.whitelisted = whitelisted
        self.blacklisted = blacklisted
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            self.objectWillChange.send()
        }
    }

    deinit {
        timer?.invalidate()
    }
}
