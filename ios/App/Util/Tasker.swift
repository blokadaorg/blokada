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

fileprivate struct TaskResult<T: Equatable, Y> {
    let argument: T
    let result: Y?
    let error: Error?
}

class Tasker<T: Equatable, Y> {

    fileprivate lazy var requests = PassthroughSubject<T, Never>()
    fileprivate lazy var response = PassthroughSubject<TaskResult<T, Y>, Never>()

    fileprivate lazy var processingRepo = Repos.processingRepo

    fileprivate let owner: String
    private let debounce: Double
    private let errorIsMajor: Bool
    private let bgQueue = DispatchQueue(label: "TaskerBgQueue")
    private var cancellable: AnyCancellable? = nil

    init(_ owner: String = "Unknown", debounce: Double = DEFAULT_USER_INTERACTION_DEBOUNCE, errorIsMajor: Bool = false) {
        self.debounce = debounce
        self.owner = owner
        self.errorIsMajor = errorIsMajor
    }

    func setTask(_ task: @escaping (T) -> AnyPublisher<Y, Error>) {
        var publisher: AnyPublisher<T, Never> = requests.eraseToAnyPublisher()
        if debounce > 0 {
            publisher = requests
            .debounce(for: .seconds(debounce), scheduler: bgQueue)
            .eraseToAnyPublisher()
        }

        cancellable = publisher
        .receive(on: bgQueue)
        .map { argument in
            BlockaLogger.v("Tasker", "\(self.owner): \(argument)")
            return argument
        }
        .flatMap { argument in
            task(argument)
            .tryMap { result in
                TaskResult(argument: argument, result: result, error: nil)
            }
            .catch { err in
                return Just(TaskResult(argument: argument, result: nil, error: err))
            }
        }
        .sink(
            onValue: { it in
                if let err = it.error {
                    // TODO: what about major errors
                    self.processingRepo.notify(self.owner, err, major: self.errorIsMajor)
                } else {
                    self.processingRepo.notify(self.owner, ongoing: false)
                }
                self.response.send(it)
            }
        )
    }

    func send(_ argument: T) -> AnyPublisher<Y, Error> {
        processingRepo.notify(owner, ongoing: true)
        let responsePub = response
        // Just return first result if debounce is set, as it's used for cases when we
        // only care about the latest invocation in a short time.
        .first { it in self.debounce != 0.0 || it.argument == argument }
        .tryMap { it -> Y in
            if let err = it.error {
                throw err
            }
            return it.result!
        }
        .eraseToAnyPublisher()
        requests.send(argument)
        return responsePub
    }

}

class SimpleTasker<Y>: Tasker<Bool, Y> {

    override init(_ owner: String = "Unknown", debounce: Double = DEFAULT_USER_INTERACTION_DEBOUNCE, errorIsMajor: Bool = false) {
        super.init(owner, debounce: debounce, errorIsMajor: errorIsMajor)
    }

    func send() -> AnyPublisher<Y, Error> {
        processingRepo.notify(owner, ongoing: true)
        let responsePub = response
        .first()
        .tryMap { it -> Y in
            if let err = it.error {
                throw err
            }
            return it.result!
        }
        .eraseToAnyPublisher()
        requests.send(true)
        return responsePub
    }

}
