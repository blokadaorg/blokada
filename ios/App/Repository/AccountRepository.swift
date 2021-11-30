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
import UIKit

class AccountRepository {

    private let log = Logger("AccRepo")
    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private lazy var local = Factories.persistenceLocal
    private lazy var remote = Factories.persistenceRemote
    private lazy var remoteLegacy = Factories.persistenceRemoteLegacy
    private lazy var crypto = Factories.crypto
    private lazy var api = Factories.apiForCurrentUser

    private lazy var account = Pubs.account
    private lazy var writeError = Pubs.writeError
    private lazy var writeAccount = Pubs.writeAccount
    private lazy var foreground = Pubs.foreground

    private let bgQueue = DispatchQueue(label: "AccRepoBgQueue")

    private lazy var proposeAccountRequests = PassthroughSubject<Account, Never>()
    private lazy var refreshAccountRequests = PassthroughSubject<AccountId, Never>()
    private lazy var restoreAccountRequests = PassthroughSubject<AccountId, Never>()
    private lazy var lastAccountRequestTimestamp = CurrentValueSubject<Double, Never>(0)

    private let ACCOUNT_REFRESH_SEC: Double = 10 * 60 // Same as on Android

    // Subscribers with lifetime same as the repository
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFromPersistenceOrCreateAccount()
        listenToProposeAccountRequests()
        listenToRefreshAccountRequests()
        listenToRestoreAccountRequests()
        refreshAccountPeriodically()
    }
    
    // Gets account from API based on user entered account ID. Does sanitization.
    func restoreAccount(_ newAccountId: AccountId) {
        restoreAccountRequests.send(newAccountId)
    }

    // Accepts account received from the payment callback (usually old receipt).
    func proposeAccount(_ newAccount: Account) {
        proposeAccountRequests.send(newAccount)
    }

    private func loadFromPersistenceOrCreateAccount() {
        Publishers.CombineLatest(
            self.loadAccountFromPersistence(),
            self.loadKeypairFromPersistence()
        )
        .tryMap { it in
            try self.validateAccount(it.0, it.1)
            return AccountWithKeypair(account: it.0, keypair: it.1)
        }
        .tryCatch { err -> AnyPublisher<AccountWithKeypair, Error> in
            // TODO: create new user on any error?
            if err as? CommonError == CommonError.emptyResult {
                return self.createNewUser()
            }
            throw err
        }
        .sink(
            onValue: { it in self.writeAccount.send(it) },
            onFailure: { err in self.writeError.send(err) }
        )
        .store(in: &cancellables)
    }

    // Receives Account object to be verified and saved. No request, but may regen keys.
    func listenToProposeAccountRequests() {
        proposeAccountRequests
        .debounce(for: 0.3, scheduler: bgQueue)
        //.removeDuplicates()
        .combineLatest(self.account)
        .tryMap { it -> (Account, AccountWithKeypair) in
            try self.validateAccountId(it.0.id)
            return it
        }
        .flatMap { it -> AnyPublisher<(Account, Keypair), Error> in
            let accountPublisher: AnyPublisher<Account, Error> = Just(it.0)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            var keypairPublisher: AnyPublisher<Keypair, Error> = Just(it.1.keypair)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()

            if it.1.account.id != it.0.id {
                keypairPublisher = self.crypto.generateKeypair()
            }

            return Publishers.CombineLatest(
                accountPublisher,
                keypairPublisher
            )
            .eraseToAnyPublisher()
        }
        .tryMap { it in
            try self.validateAccount(it.0, it.1)
            return AccountWithKeypair(account: it.0, keypair: it.1)
        }
        .sink(
            onValue: { it in self.writeAccount.send(it) },
            onFailure: { err in self.writeError.send(err) }
        )
        .store(in: &cancellables)
    }

    // Account ID is sanitised and validated, do the request and update Account model
    func listenToRefreshAccountRequests() {
        refreshAccountRequests
        .flatMap { accountId in
            self.api.client.getAccount(id: accountId)
        }
        .sink(
            onValue: { it in
                self.proposeAccountRequests.send(it)
                self.lastAccountRequestTimestamp.send(Date().timeIntervalSince1970)
            },
            onFailure: { err in self.writeError.send(err) }
        )
        .store(in: &cancellables)
    }

    // Account ID is input from user, sanitize it and then forward to do the refresh
    func listenToRestoreAccountRequests() {
        restoreAccountRequests
        .debounce(for: 0.3, scheduler: bgQueue)
        .removeDuplicates()
        .map { accountId in accountId.lowercased().trimmingCharacters(in: CharacterSet.whitespaces) }
        .tryMap { accountId in
            try self.validateAccountId(accountId)
            return accountId
        }
        .sink(
            onValue: { it in self.refreshAccountRequests.send(it) },
            onFailure: { err in self.writeError.send(err) }
        )
        .store(in: &cancellables)
    }

    // When app enters foreground, periodically refresh account
    private func refreshAccountPeriodically() {
        foreground
        .filter { foreground in foreground == true }
        .debounce(for: 2, scheduler: bgQueue)
        .removeDuplicates()
        .combineLatest(self.lastAccountRequestTimestamp)
        .map { it in it.1 }
        .filter { lastRefresh in
            lastRefresh < Date().timeIntervalSince1970 - self.ACCOUNT_REFRESH_SEC
        }
        .combineLatest(self.account)
        .map { it in it.1 }
        .sink(
            onValue: { it in
                // This is not ideal as the timestamp may not be published yet on the next call
                // But long debounce seems to fix it.
                self.lastAccountRequestTimestamp.send(Date().timeIntervalSince1970)
                self.refreshAccountRequests.send(it.account.id)
            }
        )
        .store(in: &cancellables)
    }

    private func createNewUser() -> AnyPublisher<AccountWithKeypair, Error> {
        return Publishers.CombineLatest(
            self.api.client.postNewAccount(),
            self.crypto.generateKeypair()
        )
        .tryMap { it in
            try self.validateAccount(it.0, it.1)
            return AccountWithKeypair(account: it.0, keypair: it.1)
        }
        .eraseToAnyPublisher()
    }

    private func validateAccount(_ account: Account, _ keypair: Keypair) throws {
        try validateAccountId(account.id)
        if keypair.privateKey.isEmpty || keypair.publicKey.isEmpty {
            throw "account with empty keypair"
        }
    }

    private func validateAccountId(_ accountId: AccountId) throws {
        if accountId.isEmpty {
            throw "account with empty ID"
        }
    }

    private func saveAccountToPersistence(_ account: Account) {
        var cancellables = Set<AnyCancellable>()
        Just(account).encode(encoder: self.encoder)
        .tryMap { it -> String in
            guard let it = String(data: it, encoding: .utf8) else {
                throw "setAccount: could not encode json data to string"
            }
            return it
        }
        .tryMap { it in
            return self.remote.setString(it, forKey: "account").eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let err):
                    self.writeError.send(err)
                    break
                default:
                    break
                }
            },
            receiveValue: { it in }
        )
        .store(in: &cancellables)
    }

    private func loadAccountFromPersistence() -> AnyPublisher<Account, Error> {
        return remote.getString(forKey: "account").tryCatch { err -> AnyPublisher<String, Error> in
            // A legacy read of the account - to be removed later
            return self.remoteLegacy.getString(forKey: "account")
        }
        .tryMap { it -> Data in
            guard let it = it.data(using: .utf8) else {
                throw "failed reading persisted account data"
            }

            return it
        }
        .decode(type: Account.self, decoder: self.decoder)
        .eraseToAnyPublisher()
    }

    private func loadKeypairFromPersistence() -> AnyPublisher<Keypair, Error> {
        return local.getString(forKey: "keypair").tryMap { it -> Data in
            guard let it = it.data(using: .utf8) else {
                throw "failed reading persisted keypair data"
            }

            return it
        }
        .decode(type: Keypair.self, decoder: self.decoder)
        .tryCatch { err -> AnyPublisher<Keypair, Error> in
            // A legacy read of the keys - to be removed later
            return Publishers.CombineLatest(
                self.local.getString(forKey: "privateKey"),
                self.local.getString(forKey: "publicKey")
            ).tryMap { it in
                return Keypair(privateKey: it.0, publicKey: it.1)
            }.eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
