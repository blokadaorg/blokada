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

class SheetRepo {

    var currentSheet: AnyPublisher<ActiveSheet?, Never> {
        writeSheetQueue.map { it in
            if it.isEmpty {
                return nil
            }

            let first = it.first!
            return first
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    fileprivate let writeSheetQueue = CurrentValueSubject<[ActiveSheet?], Never>([])

    fileprivate let addSheetT = Tasker<ActiveSheet?, Ignored>("addSheet", debounce: 0)
    fileprivate let removeSheetT = SimpleTasker<Ignored>("removeSheet", debounce: 0)

    private let bgQueue = DispatchQueue(label: "SheetRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    init() {
        onAddSheet()
        onRemoveSheet()
        onNextSheetRequest_dismissTheCurrentSheet()
        onSheetDismissed_displayNextAfterShortTime()
    }

    func showSheet(_ sheet: ActiveSheet, params: Any? = nil, queue: Bool = false) {
        if !queue {
            // Will cause to close the currently open sheet if any
            addSheetT.send(nil)
        }
        addSheetT.send(sheet)
    }

    func dismiss() -> AnyPublisher<Ignored, Error> {
        return removeSheetT.send()
    }

    private func onAddSheet() {
        addSheetT.setTask { sheet in
            self.writeSheetQueue.first()
            .receive(on: RunLoop.main)
            .map { it in
                if sheet == nil && it.isEmpty {
                    return []
                } else {
                    return it + [sheet]
                }
            }
            .map { it in self.writeSheetQueue.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onRemoveSheet() {
        removeSheetT.setTask { _ in
            self.writeSheetQueue.first()
            .receive(on: RunLoop.main)
            .map { it in
                guard let first = it.first else {
                    return it
                }

                // Remove any sheets of the just displayed type from the queue.
                // We assume they all had the same value to user and just skip them.
                let filtered = it.filter { $0 != first }
                return filtered
            }
            .map { it in self.writeSheetQueue.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onNextSheetRequest_dismissTheCurrentSheet() {
        writeSheetQueue
        .filter { it in it.count >= 2 }
        .filter { it in it[1] == nil }
        .sink(onValue: { it in
            let next = Array(it.dropFirst())
            self.writeSheetQueue.send(next)
        })
        .store(in: &cancellables)
    }

    private func onSheetDismissed_displayNextAfterShortTime() {
        writeSheetQueue
        .filter { it in it.count >= 2 }
        .filter { it in it[0] == nil }
        .debounce(for: 1.0, scheduler: bgQueue)
        .sink(onValue: { it in
            let next = Array(it.dropFirst())
            self.writeSheetQueue.send(next)
        })
        .store(in: &cancellables)
    }

}

class DebugSheetRepo: SheetRepo {

    private let log = Logger("Sheet")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        currentSheet.sink(
            onValue: { it in
                self.log.v("Current: \(it)")
            }
        )
        .store(in: &cancellables)

        writeSheetQueue.sink(
            onValue: { it in
                self.log.v("Queue: \(it)")
            }
        )
        .store(in: &cancellables)
    }

}
