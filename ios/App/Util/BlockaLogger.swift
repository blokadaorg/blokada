//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class BlockaLogger {

    var component: String

    init(_ component: String) {
        self.component = component
    }

    func e(_ message: String) {
        log(LogPrio.ERR.rawValue, message)
    }

    func w(_ message: String) {
        log(LogPrio.WARN.rawValue, message)
    }

    func v(_ message: String) {
        log(LogPrio.VERBOSE.rawValue, message)
    }

    func log(_ priority: Int, _ message: String) {
        let line = BlockaLogger.makeLine(priority, component, message)
        LoggerSaver.log(line)
    }

    static func e(_ component: String, _ message: String) {
        let line = makeLine(LogPrio.ERR.rawValue, component, message)
        LoggerSaver.log(line)
    }

    static func w(_ component: String, _ message: String) {
        let line = makeLine(LogPrio.WARN.rawValue, component, message)
        LoggerSaver.log(line)
    }

    static func v(_ component: String, _ message: String) {
        let line = makeLine(LogPrio.VERBOSE.rawValue, component, message)
        LoggerSaver.log(line)
    }

    private static func makeLine(_ priority: Int, _ component: String, _ message: String) -> String {
        return "\(priorityToLetter(priority: priority)) \(component.padding(toLength: 10, withPad: " ", startingAt: 0)) \(message)"
    }

    private static func priorityToLetter(priority: Int) -> String {
        switch priority {
        case LogPrio.ERR.rawValue:
            return "E"
        case LogPrio.WARN.rawValue:
            return "W"
        default:
            return " "
        }
    }
}

enum LogPrio: Int {
    case ERR = 6
    case WARN = 5
    case VERBOSE = 2
}
