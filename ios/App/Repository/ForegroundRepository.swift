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
import Combine

class ForegroundRepository {

    var foreground: AnyPublisher<IsForeground, Never> {
        self.writeForeground.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeForeground = CurrentValueSubject<IsForeground?, Never>(nil)

    func onForeground() {
        writeForeground.send(true)
    }

    func onBackground() {
        writeForeground.send(false)
    }

}

class DebugForegroundRepository: ForegroundRepository {

    private let log = Logger("FgRepo")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        foreground.sink(
            onValue: { it in self.log.v("Foreground: \(it)") }
        )
        .store(in: &cancellables)
    }

    func injectForeground(isForeground: Bool) {
        writeForeground.send(isForeground)
    }

}
