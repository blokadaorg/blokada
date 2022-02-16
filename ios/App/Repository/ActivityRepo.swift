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

class ActivityRepo: Startable {

    var entriesHot: AnyPublisher<[HistoryEntry], Never> {
        writeEntries.compactMap { $0 }.eraseToAnyPublisher()
    }

    var allowedListHot: AnyPublisher<[String], Never> {
        writeCustomList.compactMap { $0 }
        .map { it in it.filter { $0.action == "allow" }.map { $0.domain_name } }
        .eraseToAnyPublisher()
    }

    var deniedListHot: AnyPublisher<[String], Never> {
        writeCustomList.compactMap { $0 }
        .map { it in it.filter { $0.action == "block" }.map { $0.domain_name } }
        .eraseToAnyPublisher()
    }

    var customList: AnyPublisher<[CustomListEntry], Never> {
        writeCustomList.compactMap { $0 }.eraseToAnyPublisher()
    }

    var devicesHot: AnyPublisher<[String], Never> {
        entriesHot.map {
            entries in entries.map { $0.device }.unique()
        }.eraseToAnyPublisher()
    }

    private lazy var api = Services.apiForCurrentUser

    private lazy var activeTabHot = Repos.navRepo.activeTabHot

    fileprivate let writeEntries = CurrentValueSubject<[HistoryEntry]?, Never>(nil)
    fileprivate let writeCustomList = CurrentValueSubject<[CustomListEntry]?, Never>(nil)
    fileprivate let fetchEntriesT = SimpleTasker<Ignored>("fetchEntries")
    fileprivate let fetchCustomListT = SimpleTasker<Ignored>("fetchCustomList")
    fileprivate let updateCustomListT = Tasker<CustomListEntry, Ignored>("updateCustomList")

    private var cancellables = Set<AnyCancellable>()

    func start() {
        onFetchEntries()
        onFetchCustomList()
        onUpdateCustomList()
        onActivityTab_RefreshActivity()
    }

    func allow(_ entry: HistoryEntry) {
        updateCustomListT.send(CustomListEntry(
            domain_name: entry.name, action: "allow"
        ))
    }

    func unallow(_ entry: HistoryEntry) {
        updateCustomListT.send(CustomListEntry(
            domain_name: entry.name, action: "fallthrough"
        ))
    }

    func deny(_ entry: HistoryEntry) {
        updateCustomListT.send(CustomListEntry(
            domain_name: entry.name, action: "block"
        ))
    }

    func undeny(_ entry: HistoryEntry) {
        updateCustomListT.send(CustomListEntry(
            domain_name: entry.name, action: "fallthrough"
        ))
    }

    func refresh() {
        fetchEntriesT.send()
        fetchCustomListT.send()
    }

    private func onFetchEntries() {
        fetchEntriesT.setTask { _ in Just(true)
            .flatMap { _ in self.api.getActivityForCurrentUserAndDevice() }
            .tryMap { it in convertActivity(activity: it) }
            .tryMap { it in self.writeEntries.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onFetchCustomList() {
        fetchCustomListT.setTask { _ in Just(true)
            .flatMap { _ in self.api.getCustomListForCurrentUser() }
            .tryMap { it in self.writeCustomList.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onUpdateCustomList() {
        updateCustomListT.setTask { entry in Just(entry)
            // Post the custom list update to backend
            .flatMap { _ -> AnyPublisher<Ignored, Error> in
                if entry.action == "fallthrough" {
                    return self.api.deleteCustomListForCurrentUser(entry.domain_name)
                } else {
                    return self.api.postCustomListForCurrentUser(entry)
                }
            }
            // Update our local cache for a quick UX
            .flatMap { _ in
                self.customList.first()
            }
            .tryMap { it -> [CustomListEntry] in it.map {
                if $0.domain_name == entry.domain_name {
                    return entry
                } else {
                    return $0
                }
            }}
            .tryMap { it in self.writeCustomList.send(it) }
            // But also issue a get request to get in sync
            .flatMap { it in self.fetchCustomListT.send() }
            .eraseToAnyPublisher()
        }
    }

    private func onActivityTab_RefreshActivity() {
        activeTabHot.filter { it in it == .Activity }
        .sink(onValue: { it in self.refresh() })
        .store(in: &cancellables)
    }

}
