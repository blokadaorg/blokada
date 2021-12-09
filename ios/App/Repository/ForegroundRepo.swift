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

class ForegroundRepo {

    // All foreground / background events from the SceneDelegate
    var foregroundHot: AnyPublisher<IsForeground, Never> {
        self.writeForeground.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    // Filtered IsForeground = true events, debounced to avoid user flippy-flap
    var enteredForegroundHot: AnyPublisher<IsForeground, Never> {
        foregroundHot
        .filter { it in it == true }
        .debounce(for: 1, scheduler: bgQueue)
        .eraseToAnyPublisher()
    }

    private let bgQueue = DispatchQueue(label: "FgRepoBgQueue")

    fileprivate let writeForeground = CurrentValueSubject<IsForeground?, Never>(nil)

    func onForeground() {
        writeForeground.send(true)
    }

    func onBackground() {
        writeForeground.send(false)
    }

}

class DebugForegroundRepo: ForegroundRepo {

    private let log = Logger("FgRepo")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        foregroundHot.sink(
            onValue: { it in self.log.v("Foreground: \(it)") }
        )
        .store(in: &cancellables)
    }

    func injectForeground(isForeground: Bool) {
        writeForeground.send(isForeground)
    }

}
