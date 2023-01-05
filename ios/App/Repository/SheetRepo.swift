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

class SheetRepo: Startable {

    var currentSheet: AnyPublisher<ActiveSheet?, Never> {
        writeCurrentSheet.removeDuplicates().eraseToAnyPublisher()
    }

    var showPauseMenu: AnyPublisher<Bool, Never> {
        writeShowPauseMenu.removeDuplicates().compactMap { $0 }.eraseToAnyPublisher()
    }

    fileprivate let writeCurrentSheet = CurrentValueSubject<ActiveSheet?, Never>(nil)
    fileprivate let writeSheetQueue = CurrentValueSubject<[ActiveSheet?], Never>([nil])
    fileprivate let writeShowPauseMenu = CurrentValueSubject<Bool?, Never>(nil)

    fileprivate let addSheetT = Tasker<ActiveSheet?, Ignored>("addSheet", debounce: 0)
    fileprivate let removeSheetT = SimpleTasker<Ignored>("removeSheet", debounce: 0)
    fileprivate let syncClosedSheetT = SimpleTasker<Ignored>("syncClosedSheet", debounce: 0)

    private let bgQueue = DispatchQueue(label: "SheetRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    func start() {
        onAddSheet()
        onRemoveSheet()
        onSyncClosedSheet()
        onSheetQueue_pushToCurrent()
        onSheetDismissed_displayNextAfterShortTime()
    }

    func showSheet(_ sheet: ActiveSheet, params: Any? = nil) {
        currentSheet.first()
        .flatMap { it -> AnyPublisher<Ignored, Error> in
            if it != nil {
                return self.dismiss()
                .delay(for: 1.0, scheduler: self.bgQueue)
                .eraseToAnyPublisher()
            } else {
                return Just(true)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            }
        }
        .flatMap { _ in self.addSheetT.send(sheet) }
        .sink()
        .store(in: &cancellables)
    }

    func dismiss() -> AnyPublisher<Ignored, Error> {
        return removeSheetT.send()
    }

    func onDismissed() {
        self.removeSheetT.send()
    }

    func showPauseMenu(_ show: Bool) {
        writeShowPauseMenu.send(show)
    }

    private func onAddSheet() {
        addSheetT.setTask { sheet in
            self.writeSheetQueue.first()
            .receive(on: RunLoop.main)
            .map { it in
                if it.count == 1 && it.first ?? nil == nil {
                    // Put the new sheet directly to avoid delay
                    return [sheet]
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
                if it.first ?? nil != nil {
                    return [nil] + Array(it.dropFirst())
                } else {
                    return it
                }
            }
            .map { it in self.writeSheetQueue.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onSyncClosedSheet() {
        syncClosedSheetT.setTask { _ in
            self.writeSheetQueue.first()
            .receive(on: RunLoop.main)
            .map { it in
                if it.first ?? nil != nil {
                    return [nil] + Array(it.dropFirst())
                } else {
                    return it
                }
            }
            .map { it in self.writeSheetQueue.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onSheetQueue_pushToCurrent() {
        writeSheetQueue
        .flatMap { queue in
            Publishers.CombineLatest(Just(queue), self.currentSheet.first())
        }
        .map { it in
            let (queue, _) = it
            let firstInQueue = queue.first ?? nil
            return firstInQueue
        }
        .sink(onValue: { it in
            self.writeCurrentSheet.send(it)
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

    private let log = BlockaLogger("Sheet")
    private var cancellables = Set<AnyCancellable>()

    override func start() {
        super.start()

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
