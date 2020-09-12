//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class Logger {

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
        let line = Logger.makeLine(priority, component, message)
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
