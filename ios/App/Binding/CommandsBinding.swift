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
import Flutter
import Factory

private struct CommandTimeoutError: LocalizedError {
    let command: CommandName

    var errorDescription: String? {
        "Timed out waiting for Flutter readiness before dispatching \(command)"
    }
}

final class PendingCompletionCommand {
    let command: CommandName
    let p1: String?
    let p2: String?
    let completion: (Result<Void, Error>) -> Void
    var timeoutWorkItem: DispatchWorkItem?

    init(
        command: CommandName,
        p1: String?,
        p2: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.command = command
        self.p1 = p1
        self.p2 = p2
        self.completion = completion
    }
}

class CommandsBinding: CommandOps {
    @Injected(\.flutter) private var flutter
    
    private let log = BlockaLogger("Command")
    private let readyTimeoutSec: TimeInterval = 25

    lazy var cmd = CommandEvents(binaryMessenger: flutter.getMessenger())
    
    var canAcceptCommands = false
    var queue: [(CommandName, String?, String?)] = []
    var completionQueue: [PendingCompletionCommand] = []
    
    init() {
        CommandOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doCanAcceptCommands(completion: @escaping (Result<Void, Error>) -> Void) {
        canAcceptCommands = true
        log.w("Flutter bridge is ready, replaying \(queue.count) queued commands and \(completionQueue.count) queued completion commands")
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
        let queuedCompletionCommands = completionQueue
        completionQueue = []
        for item in queuedCompletionCommands {
            item.timeoutWorkItem?.cancel()
            log.w("Replaying queued completion command \(item.command)")
            dispatchCompletionCommand(item.command, p1: item.p1, p2: item.p2, completion: item.completion)
        }
        completion(.success(()))
    }

    func execute(_ command: CommandName) {
        if canAcceptCommands {
            cmd.onCommand(command: "\(command)", m: 2) { _ in }
        } else {
            log.v("Queueing command \(command)")
            queue.append((command, nil, nil))
        }
    }
    
    func executeWithCompletion(_ command: CommandName, completion: @escaping (Result<Void, Error>) -> Void) {
        if canAcceptCommands {
            dispatchCompletionCommand(command, p1: nil, p2: nil, completion: completion)
        } else {
            enqueueCompletionCommand(command, p1: nil, p2: nil, completion: completion)
        }
    }

    func executeWithCompletion(_ command: CommandName, _ p1: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if canAcceptCommands {
            dispatchCompletionCommand(command, p1: p1, p2: nil, completion: completion)
        } else {
            enqueueCompletionCommand(command, p1: p1, p2: nil, completion: completion)
        }
    }

    func executeWithCompletion(_ command: CommandName, _ p1: String, _ p2: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if canAcceptCommands {
            dispatchCompletionCommand(command, p1: p1, p2: p2, completion: completion)
        } else {
            enqueueCompletionCommand(command, p1: p1, p2: p2, completion: completion)
        }
    }

    func execute(_ command: CommandName, _ p1: String) {
        if canAcceptCommands {
            cmd.onCommandWithParam(command: "\(command)", p1: p1, m: 2) { _ in }
        } else {
            log.v("Queueing command \(command) with payload")
            queue.append((command, p1, nil))
        }
    }

    func execute(_ command: CommandName, _ p1: String, _ p2: String) {
        if canAcceptCommands {
            cmd.onCommandWithParams(command: "\(command)", p1: p1, p2: p2, m: 2) { _ in }
        } else {
            log.v("Queueing command \(command) with params")
            queue.append((command, p1, p2))
        }
    }

    private func dispatchCompletionCommand(
        _ command: CommandName,
        p1: String?,
        p2: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        log.w("Dispatching completion command \(command)")
        let handleResult: (Result<Void, FlutterError>) -> Void = { [weak self] result in
            switch result {
            case .success:
                self?.log.v("Completed command \(command)")
                completion(.success(()))
            case .failure(let error):
                self?.log.e("Command \(command) failed: \(error)")
                completion(.failure(error))
            }
        }

        if let p1, let p2 {
            cmd.onCommandWithParams(command: "\(command)", p1: p1, p2: p2, m: 2) { result in
                handleResult(result)
            }
            return
        }

        if let p1 {
            cmd.onCommandWithParam(command: "\(command)", p1: p1, m: 2) { result in
                handleResult(result)
            }
            return
        }

        cmd.onCommand(command: "\(command)", m: 2) { result in
            handleResult(result)
        }
    }

    private func enqueueCompletionCommand(
        _ command: CommandName,
        p1: String?,
        p2: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let item = PendingCompletionCommand(command: command, p1: p1, p2: p2, completion: completion)
        let timeout = DispatchWorkItem { [weak self, weak item] in
            guard let self, let item else { return }
            guard let index = self.completionQueue.firstIndex(where: { $0 === item }) else { return }

            self.completionQueue.remove(at: index)

            let error = CommandTimeoutError(command: command)
            self.log.e("Queued completion command \(command) timed out before Flutter became ready")
            item.completion(.failure(error))
        }

        item.timeoutWorkItem = timeout
        log.w("Queueing completion command \(command) until Flutter is ready")
        completionQueue.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + readyTimeoutSec, execute: timeout)
    }
}

extension Container {
    var commands: Factory<CommandsBinding> {
        self { CommandsBinding() }.singleton
    }
}
