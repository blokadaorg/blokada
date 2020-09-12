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

typealias Callback<T> = ((Error?, T?) -> Void)

typealias Ok<T> = (T) -> Void
typealias Fail = (Error) -> Void

struct Cb<T> {
    let ok: Ok<T>
    let fail: Fail
}

extension Thread {

    var threadName: String {
        if let currentOperationQueue = OperationQueue.current?.name {
            return "OperationQueue: \(currentOperationQueue)"
        } else if let underlyingDispatchQueue = OperationQueue.current?.underlyingQueue?.label {
            return "DispatchQueue: \(underlyingDispatchQueue)"
        } else {
            let name = __dispatch_queue_get_label(nil)
            return String(cString: name, encoding: .utf8) ?? Thread.current.description
        }
    }
}

func onMain(run: @escaping () -> Void) {
    DispatchQueue.main.async {
        run()
    }
}

let bgThread = DispatchQueue(label: "background.thread")

func onBackground(run: @escaping () -> Void) {
    bgThread.async {
        run()
    }
}

final class Atomic<T> {

    private let sema = DispatchSemaphore(value: 1)
    private var _value: T

    init (_ value: T) {
        _value = value
    }

    var value: T {
        get {
            sema.wait()
            defer {
                sema.signal()
            }
            return _value
        }
        set {
            sema.wait()
            _value = newValue
            sema.signal()
        }
    }

    func swap(_ value: T) -> T {
        sema.wait()
        let v = _value
        _value = value
        sema.signal()
        return v
    }
}
