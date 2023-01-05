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

class AccountRepo: Startable {

    var accountHot: AnyPublisher<AccountWithKeypair, Never> {
        self.writeAccount.compactMap { $0 }.eraseToAnyPublisher()
    }

    var accountIdHot: AnyPublisher<AccountId, Never> {
        self.accountHot.map { it in it.account.id }.removeDuplicates().eraseToAnyPublisher()
    }

    var accountTypeHot: AnyPublisher<AccountType, Never> {
        self.writeAccountType.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeAccount = CurrentValueSubject<AccountWithKeypair?, Never>(nil)
    fileprivate let writeAccountType = CurrentValueSubject<AccountType?, Never>(nil)

    fileprivate let accountInitT = Tasker<Ignored, Bool>("accountInit")
    fileprivate let proposeAccountT = Tasker<Account, Bool>("proposeAccount")
    fileprivate let refreshAccountT = Tasker<AccountId, Account>("refreshAccount", debounce: 0.0)
    fileprivate let restoreAccountT = Tasker<AccountId, Account>("restoreAccount")

    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot
    private lazy var activeTabHot = Repos.navRepo.activeTabHot

    private lazy var local = Services.persistenceLocal
    private lazy var remote = Services.persistenceRemote
    private lazy var remoteLegacy = Services.persistenceRemoteLegacy
    private lazy var crypto = Services.crypto
    private lazy var api = Services.api
    private lazy var timer = Services.timer
    private lazy var dialog = Services.dialog

    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "AccountRepoBgQueue")
    private let lastAccountRequestTimestamp = Atomic<Double>(0)

    private let ACCOUNT_REFRESH_SEC: Double = 10 * 60 // Same as on Android

    func start() {
        onAccountInit()
        onProposeAccountRequests()
        onRefreshAccountRequests()
        onRestoreAccountRequests()
        onAccountExpiring_RefreshAccount()
        onAccountAboutToExpire_MarkExpiredAndInformUser()
        onAccountChanged_EmitAccountType()
        onForeground_RefreshAccountPeriodically()
        onSettingsTab_RefreshAccount()
        accountInitT.send(true)
    }

    // Gets account from API based on user entered account ID. Does sanitization.
    func restoreAccount(_ newAccountId: AccountId) -> AnyPublisher<Account, Error> {
        return restoreAccountT.send(newAccountId)
    }

    // Accepts account received from the payment callback (usually old receipt).
    func proposeAccount(_ newAccount: Account) -> AnyPublisher<Bool, Error> {
        return proposeAccountT.send(newAccount)
    }

    private func onAccountInit() {
        accountInitT.setTask { _ in
            self.loadFromPersistenceOrCreateAccount()
            // A delayed retry (total 3 attemps spread 1-5 sec at random)
            .tryCatch { error -> AnyPublisher<AccountWithKeypair, Error> in
                return self.loadFromPersistenceOrCreateAccount()
                .delay(for: DispatchQueue.SchedulerTimeType.Stride(integerLiteral: Int.random(in: 1..<5)), scheduler: self.bgQueue)
                .retry(2)
                .eraseToAnyPublisher()
            }
            .map { it in self.writeAccount.send(it) }
            .map { _ in true }
            // Show dialog and rethrow error (user have to retry)
            .tryCatch { err in
                self.dialog.showAlert(
                    message: L10n.errorCreatingAccount,
                    header: L10n.alertErrorHeader,
                    okText: L10n.universalActionContinue,
                    okAction: { self.accountInitT.send(true) }
                )
                .tryMap { _ -> Ignored in throw err }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
    }

    private func loadFromPersistenceOrCreateAccount() -> AnyPublisher<AccountWithKeypair, Error> {
        return Publishers.CombineLatest(
            self.loadAccountFromPersistence(),
            self.loadKeypairFromPersistence()
        )
        .tryMap { it in
            try self.validateAccount(it.0, it.1)
            return AccountWithKeypair(account: it.0, keypair: it.1)
        }
        .tryCatch { err -> AnyPublisher<AccountWithKeypair, Error> in
            if err as? CommonError == CommonError.emptyResult {
                return self.createNewUser()
            }
            throw err
        }
        .flatMap { it in
            Publishers.CombineLatest(
                self.saveAccountToPersistence(it.account),
                self.saveKeypairToPersistence(it.keypair)
            )
            .tryMap { _ in it }
        }
        .eraseToAnyPublisher()
    }

    // Receives Account object to be verified and saved. No request, but may regen keys.
    private func onProposeAccountRequests() {
        proposeAccountT.setTask { account in Just(account)
            .flatMap { it in Publishers.CombineLatest(
                Just(it), self.accountHot.first()
            )}
            .tryMap { it -> (Account, AccountWithKeypair?) in
                try self.validateAccountId(it.0.id)
                return it
            }
            .flatMap { it -> AnyPublisher<(Account, BlockaKeypair), Error> in
                let accountPublisher: AnyPublisher<Account, Error> = Just(it.0)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
                var keypairPublisher: AnyPublisher<BlockaKeypair, Error> = Fail<BlockaKeypair, Error>(error: "No publisher set")
                    .eraseToAnyPublisher()

                if let acc = it.1, acc.account.id == it.0.id {
                    // Use same keypair if account ID hasn't changed
                    keypairPublisher = Just(acc.keypair)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                } else {
                    keypairPublisher = self.crypto.generateKeypair()
                }

                return Publishers.CombineLatest(
                    accountPublisher,
                    keypairPublisher
                )
                .eraseToAnyPublisher()
            }
            .tryMap { it -> AccountWithKeypair in
                try self.validateAccount(it.0, it.1)
                return AccountWithKeypair(account: it.0, keypair: it.1)
            }
            .flatMap { it in
                Publishers.CombineLatest(
                    self.saveAccountToPersistence(it.account),
                    self.saveKeypairToPersistence(it.keypair)
                )
                .tryMap { _ in it }
            }
            .tryMap { it in
                self.writeAccount.send(it)
                return true
            }
            .eraseToAnyPublisher()
        }
    }

    // Account ID is sanitised and validated, do the request and update Account model
    private func onRefreshAccountRequests() {
        refreshAccountT.setTask { accountId in
            Just(accountId)
            .flatMap { accountId in
                self.api.getAccount(id: accountId)
            }
            .tryMap { account -> Account in
                self.lastAccountRequestTimestamp.value = Date().timeIntervalSince1970
                self.proposeAccountT.send(account)
                return account
            }
            .eraseToAnyPublisher()
        }
    }

    // Account ID is input from user, sanitize it and then forward to do the refresh
    private func onRestoreAccountRequests() {
        restoreAccountT.setTask { accountId in
            Just(accountId)
            // .removeDuplicates()
            .map { accountId in accountId.lowercased().trimmingCharacters(in: CharacterSet.whitespaces) }
            .tryMap { accountId in
                try self.validateAccountId(accountId)
                return accountId
            }
            .flatMap { accountId in
                self.refreshAccountT.send(accountId)
            }
            .eraseToAnyPublisher()
        }
    }

    // Re-check account just before it expires in case it was extended externally.
    // We do it to make sure we still have connectivity.
    private func onAccountExpiring_RefreshAccount() {
        accountHot.map { it in it.account }
        .sink(onValue: { it in
            let until = it.activeUntil()?.shortlyBefore() ?? Date()
            if until > Date() {
                self.timer.createTimer(NOTIF_ACC_EXP, when: until)
                .flatMap { _ in self.timer.obtainTimer(NOTIF_ACC_EXP) }
                .sink(
                    onFailure: { err in
                        BlockaLogger.e("AppRepo", "Acc expiration timer failed: \(err)")
                    },
                    onSuccess: {
                        BlockaLogger.v("AppRepo", "Account soon to expire, refreshing")
                        self.refreshAccountT.send(it.id)
                        .sink(onFailure: { err in
                            // If cannot refresh, emit expired account manually.
                            // We may be out of connectivity.
                            self.proposeAccount(Account(
                                id: it.id, active_until: nil, active: false, type: "libre"
                            ))
                        })
                        .store(in: &self.cancellables)
                    }
                )
                .store(in: &self.cancellables) // TODO: not sure if it's the best idea
            } else {
                self.timer.cancelTimer(NOTIF_ACC_EXP)
            }
        })
        .store(in: &cancellables)
    }

    private func onAccountAboutToExpire_MarkExpiredAndInformUser() {
        accountHot.map { it in it.account }
        .filter { it in
            if !it.isActive() {
                return false
            }

            if let until = it.activeUntil(), until.shortlyBefore() < Date() {
                return true
            } else {
                return false
            }
        }
        .sink(onValue: { it in
            // Mark account as expired internally
            BlockaLogger.v(
                "AppRepo",
                 "Marking account as expired, now: \(Date()), acc: \(it.activeUntil()?.shortlyBefore())"
            )

            self.proposeAccount(Account(
                id: it.id, active_until: nil, active: false, type: "libre"
            ))

            // Inform user
            self.dialog.showAlert(
                message: L10n.notificationAccBody,
                header: L10n.notificationAccHeader
            )
            .sink()
            .store(in: &self.cancellables)
        })
        .store(in: &cancellables)
    }

    private func onAccountChanged_EmitAccountType() {
        accountHot.map { it in it.account.type }
        .map { it in mapAccountType(it) }
        .sink(onValue: { it in self.writeAccountType.send(it) })
        .store(in: &cancellables)
    }

    // When app enters foreground, periodically refresh account
    private func onForeground_RefreshAccountPeriodically() {
        enteredForegroundHot
        .filter { it in
            self.lastAccountRequestTimestamp.value < Date().timeIntervalSince1970 - self.ACCOUNT_REFRESH_SEC
        }
        .flatMap { it in self.accountHot.first() }
        .sink(
            onValue: { it in
                self.lastAccountRequestTimestamp.value = Date().timeIntervalSince1970
                self.refreshAccountT.send(it.account.id)
            }
        )
        .store(in: &cancellables)
    }

    private func onSettingsTab_RefreshAccount() {
        activeTabHot
        .filter { it in it == .Settings }
        .flatMap { it in self.accountHot.first() }
        .sink(onValue: { it in self.refreshAccountT.send(it.account.id) })
        .store(in: &cancellables)
    }

    private func createNewUser() -> AnyPublisher<AccountWithKeypair, Error> {
        BlockaLogger.w("Account", "Creating new user")
        return Publishers.CombineLatest(
            self.api.postNewAccount(),
            self.crypto.generateKeypair()
        )
        .tryMap { it in
            try self.validateAccount(it.0, it.1)
            return AccountWithKeypair(account: it.0, keypair: it.1)
        }
        .eraseToAnyPublisher()
    }

    private func validateAccount(_ account: Account, _ keypair: BlockaKeypair) throws {
        try validateAccountId(account.id)
        if keypair.privateKey.isEmpty || keypair.publicKey.isEmpty {
            throw "account with empty keypair"
        }

        if Services.env.isProduction && CRYPTO_MOCKED_KEYS.contains(keypair) {
            BlockaLogger.w("Account", "Mocked keys detected, recreating account")
            throw CommonError.emptyResult
        }
    }

    private func validateAccountId(_ accountId: AccountId) throws {
        if accountId.isEmpty {
            throw "account with empty ID"
        }
    }

    private func saveAccountToPersistence(_ account: Account) -> AnyPublisher<Ignored, Error> {
        Just(account).encode(encoder: self.encoder)
        .tryMap { it -> String in
            guard let it = String(data: it, encoding: .utf8) else {
                throw "account: could not encode json data to string"
            }
            return it
        }
        .flatMap { it in
            return self.remote.setString(it, forKey: "account")
        }
        .eraseToAnyPublisher()
    }

    private func saveKeypairToPersistence(_ keypair: BlockaKeypair) -> AnyPublisher<Ignored, Error> {
        Just(keypair).encode(encoder: self.encoder)
        .tryMap { it -> String in
            guard let it = String(data: it, encoding: .utf8) else {
                throw "keypair: could not encode json data to string"
            }
            return it
        }
        .flatMap { it in
            return self.local.setString(it, forKey: "keypair")
        }
        .eraseToAnyPublisher()
    }

    private func loadAccountFromPersistence() -> AnyPublisher<Account, Error> {
        return remote.getString(forKey: "account").tryCatch { err -> AnyPublisher<String, Error> in
            // A legacy read of the account - to be removed later
            return self.remoteLegacy.getString(forKey: "account")
        }
        .tryMap { it -> Data in
            guard let it = it.data(using: .utf8) else {
                throw "account: failed reading persisted account data"
            }

            return it
        }
        .decode(type: Account.self, decoder: self.decoder)
        .eraseToAnyPublisher()
    }

    private func loadKeypairFromPersistence() -> AnyPublisher<BlockaKeypair, Error> {
        return local.getString(forKey: "keypair").tryMap { it -> Data in
            guard let it = it.data(using: .utf8) else {
                throw "keypair: failed reading persisted keypair data"
            }

            return it
        }
        .decode(type: BlockaKeypair.self, decoder: self.decoder)
        .tryCatch { err -> AnyPublisher<BlockaKeypair, Error> in
            // A legacy read of the keys - to be removed later
            return Publishers.CombineLatest(
                self.local.getString(forKey: "privateKey"),
                self.local.getString(forKey: "publicKey")
            )
            .tryMap { it in
                return BlockaKeypair(privateKey: it.0, publicKey: it.1)
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

}

class DebugAccountRepo: AccountRepo {

    private let log = BlockaLogger("AccRepo")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        accountHot.sink(
            onValue: { it in self.log.v("Account: \(it)") }
        )
        .store(in: &cancellables)
    }
}
