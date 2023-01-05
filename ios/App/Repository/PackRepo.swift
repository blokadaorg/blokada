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

class PackRepo: Startable {

    // Blocklists is server side representation of all known lists.
    private var blocklistsHot: AnyPublisher<[Blocklist], Never> {
        writeBlocklists.compactMap { $0 }.eraseToAnyPublisher()
    }

    // Intermediate representation, internal to this class.
    private var mappedBlocklistsHot: AnyPublisher<[MappedBlocklist], Never> {
        blocklistsHot.map { it in
            convertBlocklists(blocklists: it.filter { !$0.is_allowlist })
        }.eraseToAnyPublisher()
    }

    // Used internally to access the map synchronously
    private var mappedBlocklistInternal: [MappedBlocklist] = []

    // Packs is app's representation. One pack may have multiple configs.
    var packsHot: AnyPublisher<[Pack], Never> {
        writePacks.compactMap { $0 }.eraseToAnyPublisher()
    }

    private lazy var api = Services.apiForCurrentUser
    private lazy var dataSource = PackDataSource()

    private lazy var cloudRepo = Repos.cloudRepo

    fileprivate let writeBlocklists = CurrentValueSubject<[Blocklist]?, Never>(nil)
    fileprivate let writePacks = CurrentValueSubject<[Pack]?, Never>(nil)

    fileprivate let loadBlocklistsT = SimpleTasker<Ignored>("loadBlocklists", errorIsMajor: true)
    fileprivate let convertBlocklistsToPacksT = SimpleTasker<Ignored>("convertBlocklistsToPacks", errorIsMajor: true)
    fileprivate let installPackT = Tasker<Pack, Ignored>("installPack", errorIsMajor: true)
    fileprivate let uninstallPackT = Tasker<Pack, Ignored>("uninstallPack", errorIsMajor: true)

    private var cancellables = Set<AnyCancellable>()

    func start() {
        onLoadBlocklists()
        onConvertBlocklistsToPacks()
        onInstallPack()
        onUnistallPack()
        onLoadBlocklists_convertBlocklistsToPacks()
        onBlocklistsIdsChanged_sync()
        onMappedBlocklistsChanged_setField()
    }

    func installPack(_ pack: Pack) -> AnyPublisher<Ignored, Error> {
        return installPackT.send(pack)
    }

    func uninstallPack(_ pack: Pack) -> AnyPublisher<Ignored, Error> {
        return uninstallPackT.send(pack)
    }

    // When user changes configuration (selects / deselects) for a pack that is (in)active
    func changeConfig(pack: Pack, config: PackConfig) -> AnyPublisher<Ignored, Error> {
        let pack = pack.changeStatus(installed: false, config: config)
        return installPack(pack)
    }

    func getPackNameForBlocklist(list: String) -> String? {
        let packId = mappedBlocklistInternal.first(where: { $0.id == list })?.packId
        return dataSource.packs.first(where: { $0.id == packId })?.meta.title
    }

    private func onLoadBlocklists() {
        loadBlocklistsT.setTask { _ in Just(true)
            .flatMap { _ in self.api.getBlocklistsForCurrentUser() }
            .map { it in self.writeBlocklists.send(it) }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    // Converts blocklists returned by backend to internal Packs.
    // The app knows a set of Packs (defined in PackDataSource).
    // Here it checks what known packs are active in backend, and ignores the rest.
    private func onConvertBlocklistsToPacks() {
        convertBlocklistsToPacksT.setTask { _ in Just(true)
            // Get the intermediate representation, and the backend IDs of active ones.
            .flatMap { _ in Publishers.CombineLatest(
                self.cloudRepo.blocklistsHot.first(), self.mappedBlocklistsHot.first()
            )}
            .tryMap { idsAndBlocklists -> [MappedBlocklist] in
                let (activeBlocklistIds, blocklists) = idsAndBlocklists
                return blocklists.filter { it in
                    activeBlocklistIds.contains(it.id)
                }
            }
            // Map those to the known packs.
            .tryMap { mapped -> [Pack] in
                var packs = self.dataSource.packs
                var packsDict: [String: Pack] = [:]
                packs.forEach { pack in packsDict[pack.id] = pack }
                mapped.forEach { mapping in
                    let packId = mapping.packId
                    let configName = mapping.packConfig
                    let pack = packsDict[packId]

                    guard let pack = pack else {
                        return BlockaLogger.w("Pack", "reload: unknown pack id: \(packId)")
                    }

                    guard pack.configs.contains(configName) else {
                        return BlockaLogger.w("Pack", "reload: pack \(packId) doesnt know config \(configName)")
                    }

                    let newPack = pack.changeStatus(installed: true, config: configName)
                    packsDict[packId] = newPack
                    packs = packs.map { $0.id == packId ? newPack : $0 }
                }
                return packs
            }
            .tryMap { it in self.writePacks.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onLoadBlocklists_convertBlocklistsToPacks() {
        mappedBlocklistsHot
        .sink(onValue: { it in self.convertBlocklistsToPacksT.send() })
        .store(in: &cancellables)
    }

    private func onInstallPack() {
        installPackT.setTask { pack -> AnyPublisher<Ignored, Error> in
            // Select default config for this pack if none selected
            var pack = pack.changeStatus(installing: true)
            if pack.status.config.isEmpty {
                BlockaLogger.v("Pack", "installPack: selecting first config by default: \(pack.configs.first!)")
                pack = pack.changeStatus(config: pack.configs.first!)
            }

            return Just(pack)
            // Announce this pack is installing
            .flatMap { it in self.packsHot.first() }
            .tryMap { packs -> Ignored in
                let pack = pack.changeStatus(installing: true)
                let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                self.writePacks.send(newPacks)
                return true
            }
            // Get the fresh blocklists information
            .flatMap { _ in Publishers.CombineLatest(
                self.cloudRepo.blocklistsHot.first(), self.mappedBlocklistsHot.first()
            )}
            // Do the actual installation in the Cloud
            .tryMap { idsAndBlocklists -> CloudBlocklists in
                let (activeBlocklistIds, blocklists) = idsAndBlocklists

                let mapped = blocklists.filter { it in
                    // Get only mapping for selected pack
                    it.packId == pack.id
                    // And only for configs that are active for this pack
                    && pack.status.config.contains(it.packConfig)
                }

                if mapped.isEmpty {
                    throw "could not find relevant blocklist for: \(pack)"
                } else {
                    BlockaLogger.v("Pack", "New choice: \(mapped)")
                }

                // A config might have been unselected for the currently edited pack
                let oldSelectionForThisPack = blocklists.filter { $0.packId == pack.id }.map { $0.id }

                // Merge lists unique (and maybe deselect a config from current pack)
                let newActiveLists = Set(mapped.map { $0.id }).union(
                    Set(activeBlocklistIds).subtracting(oldSelectionForThisPack)
                )
                return Array(newActiveLists)
            }
            .flatMap { it -> AnyPublisher<Ignored, Error> in self.cloudRepo.setBlocklists(it) }
            // Announce this pack is not installing after successful install
            .flatMap { _ in self.packsHot.first() }
            .tryMap { packs in
                let pack = pack.changeStatus(installed: true, updatable: false, installing: false)
                let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                self.writePacks.send(newPacks)
                return true
            }
            // Announce also if failed installing
            .tryCatch { err in
                return self.packsHot.first()
                .tryMap { packs -> Ignored in
                    let pack = pack.changeStatus(installed: false, installing: false)
                    let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                    self.writePacks.send(newPacks)
                    throw err
                }
            }
            .eraseToAnyPublisher()
        }
    }
    
    private func onUnistallPack() {
        uninstallPackT.setTask { pack -> AnyPublisher<Ignored, Error> in return Just(pack)
            // Announce this pack is uninstalling
            .flatMap { it in self.packsHot.first() }
            .tryMap { packs -> Ignored in
                let pack = pack.changeStatus(installing: true)
                let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                self.writePacks.send(newPacks)
                return true
            }
            // Get the fresh blocklists information
            .flatMap { _ in Publishers.CombineLatest(
                self.cloudRepo.blocklistsHot.first(), self.mappedBlocklistsHot.first()
            )}
            // Do the actual installation in the Cloud
            .tryMap { idsAndBlocklists -> CloudBlocklists in
                let (activeBlocklistIds, blocklists) = idsAndBlocklists
                
                let mapped = blocklists.filter { it in
                    // Get only mapping for selected pack
                    it.packId == pack.id
                }

                if mapped.isEmpty {
                    throw "could not find relevant blocklist for: \(pack)"
                }

                // Merge lists unique
                let newActiveLists = Set(activeBlocklistIds).subtracting(mapped.map { $0.id })
                return Array(newActiveLists)
            }
            .flatMap { it -> AnyPublisher<Ignored, Error> in return self.cloudRepo.setBlocklists(it) }
            // Announce this pack is not installing after successful install
            .flatMap { _ in self.packsHot.first() }
            .tryMap { packs in
                let pack = pack.changeStatus(installed: false, updatable: false, installing: false)
                let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                self.writePacks.send(newPacks)
                return true
            }
            // Announce also if failed installing
            .tryCatch { err in
                return self.packsHot.first()
                .tryMap { packs -> Ignored in
                    let pack = pack.changeStatus(installed: true, installing: false)
                    let newPacks = packs.map { $0.id == pack.id ? pack : $0 }
                    self.writePacks.send(newPacks)
                    throw err
                }
            }
            .eraseToAnyPublisher()
        }
    }

    private func onBlocklistsIdsChanged_sync() {
        cloudRepo.blocklistsHot
        .sink(onValue: { it in self.loadBlocklistsT.send() })
        .store(in: &cancellables)
    }

    private func onMappedBlocklistsChanged_setField() {
        mappedBlocklistsHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.mappedBlocklistInternal = it })
        .store(in: &cancellables)
    }

}
