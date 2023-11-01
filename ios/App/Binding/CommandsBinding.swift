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

class CommandsBinding: CommandOps {
    @Injected(\.flutter) private var flutter

    lazy var cmd = CommandEvents(binaryMessenger: flutter.getMessenger())
    
    var canAcceptCommands = false
    var queue: [(CommandName, String?, String?)] = []
    
    init() {
        CommandOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doCanAcceptCommands(completion: @escaping (Result<Void, Error>) -> Void) {
        canAcceptCommands = true
        for item in queue {
            let (cmd, p1, p2) = item
            if p1 == nil {
                execute(cmd)
            } else if p2 == nil {
                execute(cmd, p1!)
            } else {
                execute(cmd, p1!, p2!)
            }
        }
        queue = []
    }

    func execute(_ command: CommandName) {
        if canAcceptCommands {
            cmd.onCommand(command: "\(command)") { _ in }
        } else {
            queue.append((command, nil, nil))
        }
    }

    func execute(_ command: CommandName, _ p1: String) {
        if canAcceptCommands {
            cmd.onCommandWithParam(command: "\(command)", p1: p1) { _ in }
        } else {
            queue.append((command, p1, nil))
        }
    }

    func execute(_ command: CommandName, _ p1: String, _ p2: String) {
        if canAcceptCommands {
            cmd.onCommandWithParams(command: "\(command)", p1: p1, p2: p2) { _ in }
        } else {
            queue.append((command, p1, p2))
        }
    }
}

extension Container {
    var commands: Factory<CommandsBinding> {
        self { CommandsBinding() }.singleton
    }
}
