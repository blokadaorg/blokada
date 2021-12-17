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
class ProcessingRepo {

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

    // OutputSubject is a CurrentValueSubject that automatically marks the owner component
    // as idle whenever it pushes a new value to this subject. It is a pattern used across
    // many repos to finish processing by pushing to a subject which is a hot publisher.
//    func createOutputSubject<T>(_ component: Any) -> CurrentValueSubject<T?, Never> {
//        let subject = CurrentValueSubject<T?, Never>(nil)
//        subject.sink(
//            onValue: { it in self.notify(component, ongoing: false)}
//        )
//        .store(in: &cancellables)
//        return subject
//    }

    
}
//
//func outputSubject<T>() -> CurrentValueSubject<T?, Never> {
//    return Repos.processingRepo.createOutputSubject(component)
//}



class DebugProcessingRepo: ProcessingRepo {

    private let log = Logger("Processing")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

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
