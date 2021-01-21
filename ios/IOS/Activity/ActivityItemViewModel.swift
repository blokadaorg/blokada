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
