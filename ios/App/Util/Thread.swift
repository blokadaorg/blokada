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

typealias Callback<T> = ((Error?, T?) -> Void)

typealias Ok<T> = (T) -> Void
typealias Faile = (Error) -> Void

struct Cb<T> {
    let ok: Ok<T>
    let fail: Faile
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

fileprivate let bgThread = DispatchQueue(label: "background.thread")

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
