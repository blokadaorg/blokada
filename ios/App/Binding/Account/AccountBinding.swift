//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

class AccountBinding: AccountOps {
    var accountHot: AnyPublisher<AccountWithKeypair, Never> {
        self.writeAccount.compactMap { $0 }.eraseToAnyPublisher()
    }

    var accountIdHot: AnyPublisher<AccountId, Never> {
        self.accountHot.map { it in it.account.id }.removeDuplicates().eraseToAnyPublisher()
    }

    var accountTypeHot: AnyPublisher<AccountType, Never> {
        self.accountHot.map { it in mapAccountType(it.account.type) }.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeAccount = CurrentValueSubject<AccountWithKeypair?, Never>(nil)

    @Injected(\.flutter) private var flutter
    @Injected(\.env) private var env
    @Injected(\.commands) private var commands

    init() {
        AccountOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    // Gets account from API based on user entered account ID. Does sanitization.
    func restoreAccount(_ newAccountId: AccountId, completion: @escaping () -> Void) {
        commands.execute(.restore, newAccountId)
    }

    func doAccountChanged(account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
        _proposeAccount(JsonAccount(
            id: account.id,
            active_until: account.activeUntil,
            active: account.active,
            type: account.type
        ))
        completion(.success(()))
    }

    // Accepts account received from the payment callback (usually old receipt).
    private func _proposeAccount(_ newAccount: JsonAccount) {
        // TODO: keypair
        writeAccount.send(AccountWithKeypair(account: newAccount, keypair: BlockaKeypair(privateKey: "nope", publicKey: "nope")))
    }
}

extension Container {
    var account: Factory<AccountBinding> {
        self { AccountBinding() }.singleton
    }
}
