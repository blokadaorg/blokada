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

// This repo is used by all other repos to report their processing state globally.
class ProcessingRepo: Startable {

    var errorsHot: AnyPublisher<ComponentError, Never> {
        self.writeError.compactMap { $0 }.eraseToAnyPublisher()
    }

    var ongoingHot: AnyPublisher<ComponentOngoing, Never> {
        self.writeOngoing.compactMap { $0 }.eraseToAnyPublisher()
    }

    var currentlyOngoingHot: AnyPublisher<[ComponentOngoing], Never> {
        self.ongoingHot.scan([]) { acc, it in
            if it.ongoing && !acc.contains(where: { $0.component == it.component }) {
                return acc + [it]
            } else if !it.ongoing && acc.contains(where: { $0.component == it.component }) {
                return acc.filter { $0.component != it.component }
            } else {
                return acc
            }
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    fileprivate let writeError = CurrentValueSubject<ComponentError?, Never>(nil)
    fileprivate let writeOngoing = CurrentValueSubject<ComponentOngoing?, Never>(nil)

    // Subscribers with lifetime same as the repository
    private var cancellables = Set<AnyCancellable>()

    func start() {
    }

    func notify(_ component: Any, _ error: Error, major: Bool) {
        writeError.send(ComponentError(
            component: String(describing: component), error: error, major: major
        ))
        notify(component, ongoing: false)
    }

    func notify(_ component: Any, ongoing: Bool) {
        writeOngoing.send(ComponentOngoing(
            component: String(describing: component), ongoing: ongoing
        ))
    }

}

class DebugProcessingRepo: ProcessingRepo {

    private let log = BlockaLogger("Processing")
    private var cancellables = Set<AnyCancellable>()

    override func start() {
        super.start()

        errorsHot.sink(
            onValue: { it in
                if it.major {
                    self.log.e("Major error: \(it.component): \(it.error)")
                } else {
                    self.log.w("Error: \(it.component): \(it.error)")
                }
            }
        )
        .store(in: &cancellables)

        currentlyOngoingHot.sink(
            onValue: { it in
                self.log.v("\(it)")
            }
        )
        .store(in: &cancellables)

    }

    func injectOngoing(_ ongoing: ComponentOngoing) {
        writeOngoing.send(ongoing)
    }

}
